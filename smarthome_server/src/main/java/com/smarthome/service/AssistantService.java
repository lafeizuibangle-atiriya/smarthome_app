package com.smarthome.service;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.common.DeviceTypes;
import com.smarthome.entity.Device;
import com.smarthome.entity.Room;
import com.smarthome.mapper.DeviceMapper;
import com.smarthome.mapper.RoomMapper;
import com.smarthome.vo.DeviceVO;
import com.smarthome.vo.HomeOverviewVO;
import com.smarthome.vo.RoomEnvironmentVO;
import com.smarthome.vo.WeatherAirVO;
import com.smarthome.vo.WeatherNowVO;
import com.smarthome.vo.WeatherWarningVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 智能助手服务（2026-11-23 新增，对应《08_智能助手方案.md》方案 B）。
 *
 * <p>处理流程：
 * <ol>
 *   <li>标准指令（开/关某房间某设备、切模式）先走关键词直答，不经过模型，响应快且 100% 成功；</li>
 *   <li>匹配不上再走大模型：把"当前家庭状态 + 联动规则 + FAQ"拼进 system prompt，
 *       模型要么直接回答，要么发起工具调用；</li>
 *   <li>工具只开放 3 个白名单（开关设备 / 切模式 / 查状态），模型做不了白名单之外的事，
 *       且后端对参数做校验（房间必须真实存在、类型必须合法）；</li>
 *   <li>任何异常都兜底成固定话术，不抛给前端白屏。</li>
 * </ol>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AssistantService {

    private final LlmClient llmClient;
    private final DeviceService deviceService;
    private final WeatherService weatherService;
    private final DeviceMapper deviceMapper;
    private final RoomMapper roomMapper;

    /** 聊天历史：内存保存每个用户最近 10 轮，重启即清空，不建表 */
    private final Map<Long, List<Map<String, String>>> history = new HashMap<>();

    private static final int MAX_TOOL_ROUNDS = 3;   // 工具调用循环上限，防模型死循环
    private static final int MAX_HISTORY_MESSAGES = 20;

    // ========================= 对外入口 =========================

    /**
     * 处理一句用户提问，返回 {reply: 回复文本, source: rule/llm/fallback}
     */
    public Map<String, Object> chat(Long userId, String question) {
        // 1. 标准指令直答（规则层）
        String ruleReply = tryRuleReply(userId, question);
        if (ruleReply != null) {
            appendHistory(userId, "user", question);
            appendHistory(userId, "assistant", ruleReply);
            return Map.of("reply", ruleReply, "source", "rule");
        }

        // 2. 未配置 API Key：关键词层管不了的问题给 FAQ 兜底
        if (!llmClient.enabled()) {
            String fallback = FALLBACK_REPLY;
            appendHistory(userId, "user", question);
            appendHistory(userId, "assistant", fallback);
            return Map.of("reply", fallback, "source", "fallback");
        }

        // 3. 大模型 + Function Calling
        try {
            String reply = chatByLlm(userId, question);
            appendHistory(userId, "user", question);
            appendHistory(userId, "assistant", reply);
            return Map.of("reply", reply, "source", "llm");
        } catch (Exception e) {
            log.warn("智能助手大模型调用失败: {}", e.getMessage());
            appendHistory(userId, "user", question);
            appendHistory(userId, "assistant", FALLBACK_REPLY);
            return Map.of("reply", FALLBACK_REPLY, "source", "fallback");
        }
    }

    // ========================= 规则层：关键词直答 =========================

    /**
     * 尝试用关键词解析标准指令。命中并执行成功返回回复文本；
     * 不像标准指令返回 null（交给大模型）。
     */
    private String tryRuleReply(Long userId, String question) {
        // 切模式："切换到自动模式" / "手动模式"
        if (question.contains("模式")) {
            if (question.contains("自动")) {
                return execMode(userId, "AUTO");
            }
            if (question.contains("手动")) {
                return execMode(userId, "MANUAL");
            }
        }
        // 开关设备：动词（开/关）+ 设备关键词（灯/风扇/门/蜂鸣器）
        Integer power = parsePower(question);
        String type = parseDeviceType(question);
        if (power == null || type == null) {
            // 意愿直答（2026-11-24）：嫌暗/嫌热这类没点名设备的意愿，按对照表直接执行。
            // 2026-11-24 实测 glm-4-flash 遇到这类输入经常反问"需要打开吗"或编造执行，
            // 所以把意愿推断从模型手里拿回来放进规则层，100% 稳定。
            // 疑问句不套用（"怎么让房间变暗"不是开灯指令）
            if (!looksLikeQuestion(question)) {
                String intentType = mapIntentType(question);
                if (intentType != null) {
                    Integer intentPower = mapIntentPower(question, intentType);
                    if (intentPower != null) {
                        return execDevice(userId, intentType, intentPower, null);
                    }
                }
            }
            return null;
        }
        Room room = parseRoom(userId, question);   // 可为 null：不带房间名就全屋找第一台
        return execDevice(userId, type, power, room);
    }

    /**
     * 执行"打开/关闭某类型设备"并生成回复。room 为 null 时全屋找第一台。
     * 规则层标准指令与意愿直答共用这一个出口，行为一致（含离线防护）。
     */
    private String execDevice(Long userId, String type, Integer power, Room room) {
        Device device = findDevice(userId, room == null ? null : room.getId(), type);
        if (device == null) {
            String where = room == null ? "全屋" : room.getName();
            return "没找到" + where + "的" + DeviceTypes.NAMES.getOrDefault(type, type)
                    + "。当前房间：" + roomNames(userId);
        }
        // 离线防护：设备不在线时下发也不会执行（硬件上报会把状态纠正回去），
        // 如实告知而不是装作成功（2026-11-23 用户实测踩过"回复已打开但没开"）
        if (device.getOnline() != null && device.getOnline() == 0) {
            return device.getName() + "当前离线，暂时无法控制。请检查设备电源和网络后重试。";
        }
        deviceService.control(device.getId(), userId, Map.of("power", power == 1 ? "on" : "off"));
        String roomName = roomNameOf(userId, device.getRoomId());
        return "已" + (power == 1 ? "打开" : "关闭") + prettyDeviceName(roomName, device.getName()) + "。";
    }

    /** 疑问句判断：带疑问词的不套用意愿对照表（"怎么让房间变暗"不是开灯指令） */
    private boolean looksLikeQuestion(String q) {
        return q.contains("吗") || q.contains("？") || q.contains("?")
                || q.contains("怎么") || q.contains("什么") || q.contains("哪些")
                || q.contains("为什么") || q.contains("如何");
    }

    /**
     * 意愿关键词 → 设备类型（与 system prompt 里的"意愿→设备对照表"同一套规则）。
     * 对照不上返回 null。
     */
    private String mapIntentType(String q) {
        if (q.contains("热") || q.contains("闷") || q.contains("通风")
                || q.contains("冷")) return DeviceTypes.FAN;
        if (q.contains("暗") || q.contains("黑") || q.contains("刺眼")) return DeviceTypes.LIGHT;
        if (q.contains("吵") || q.contains("噪")) return DeviceTypes.BEEP;
        if (q.contains("出门") || q.contains("离家") || q.contains("回家") || q.contains("进门")) {
            return DeviceTypes.GATE;
        }
        return null;
    }

    /** 意愿关键词 → 开(1)/关(0)，对照不上返回 null */
    private Integer mapIntentPower(String q, String type) {
        if (DeviceTypes.FAN.equals(type)) {
            if (q.contains("热") || q.contains("闷") || q.contains("通风")) return 1;
            if (q.contains("冷")) return 0;
        } else if (DeviceTypes.LIGHT.equals(type)) {
            if (q.contains("暗") || q.contains("黑")) return 1;
            if (q.contains("刺眼")) return 0;
        } else if (DeviceTypes.BEEP.equals(type)) {
            if (q.contains("吵") || q.contains("噪")) return 0;
        } else if (DeviceTypes.GATE.equals(type)) {
            if (q.contains("出门") || q.contains("离家")) return 0;
            if (q.contains("回家") || q.contains("进门")) return 1;
        }
        return null;
    }

    /** 从句子里解析开(1)/关(0)，解析不出返回 null */
    private Integer parsePower(String q) {
        if (q.contains("打开")) return 1;
        if (q.contains("关闭") || q.contains("关掉") || q.contains("关上")) return 0;
        if (q.contains("开")) return 1;
        if (q.contains("关")) return 0;
        return null;
    }

    /** 设备关键词 → 类型，认不出返回 null */
    private String parseDeviceType(String q) {
        if (q.contains("蜂鸣器")) return DeviceTypes.BEEP;
        if (q.contains("灯")) return DeviceTypes.LIGHT;
        if (q.contains("风扇")) return DeviceTypes.FAN;
        if (q.contains("门")) return DeviceTypes.GATE;
        return null;
    }

    /** 从句子里找用户真实存在的房间名，找不到返回 null */
    private Room parseRoom(Long userId, String q) {
        for (Room room : userRooms(userId)) {
            if (q.contains(room.getName())) {
                return room;
            }
        }
        return null;
    }

    private String execMode(Long userId, String mode) {
        deviceService.setMode(mode, userId);
        return "已切换到" + ("AUTO".equals(mode) ? "自动" : "手动") + "模式。";
    }

    // ========================= 大模型层 =========================

    private String chatByLlm(Long userId, String question) {
        List<Map<String, Object>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", buildSystemPrompt(userId)));
        List<Map<String, String>> hist = history.get(userId);
        if (hist != null) {
            for (Map<String, String> m : hist) {
                messages.add(Map.of("role", m.get("role"), "content", m.get("content")));
            }
        }
        messages.add(Map.of("role", "user", "content", question));

        List<Map<String, Object>> tools = buildToolDefinitions();

        /**
         * 【执行结果校验，2026-11-23】模型偶尔会不调用工具、直接把"已打开某某"当文本说出来
         * （实测出现：回复"已打开客厅灯"，但华为云侧没有任何下发记录，设备状态也没变）。
         * 防法：本轮若回复声称执行了操作（已打开/已关闭/已切换）却没有任何工具成功执行，
         * 就带纠正指令重试一轮；重试两次仍不达标就返回诚实的失败话术。
         */
        for (int attempt = 0; attempt < 2; attempt++) {
            boolean executed = false;
            String content = "这个问题我暂时答不上来。";

            for (int round = 0; round < MAX_TOOL_ROUNDS; round++) {
                JSONObject msg = llmClient.chatCompletion(messages, tools);
                JSONArray toolCalls = msg.getJSONArray("tool_calls");
                log.info("[助手调试] attempt={} round={} toolCalls={} content={}",
                        attempt, round, toolCalls == null ? 0 : toolCalls.size(),
                        msg.getStr("content", ""));
                if (toolCalls == null || toolCalls.isEmpty()) {
                    String text = msg.getStr("content", "");
                    content = text.isBlank() ? "这个问题我暂时答不上来。" : text;
                    break;
                }
                // 把模型的工具调用请求记回对话，再逐个执行、以 tool 角色回传结果
                messages.add(new LinkedHashMap<>(msg));
                for (int i = 0; i < toolCalls.size(); i++) {
                    JSONObject call = toolCalls.getJSONObject(i);
                    String callId = call.getStr("id", "call_" + i);
                    JSONObject fn = call.getJSONObject("function");
                    String result = execTool(userId, fn.getStr("name"),
                            JSONUtil.parseObj(fn.getStr("arguments", "{}")));
                    log.info("[助手调试] 工具调用 name={} args={} result={}",
                            fn.getStr("name"), fn.getStr("arguments"), result);
                    // 成功的执行以"已xxx"开头（失败以"错误："/"执行失败："开头）
                    if (result.startsWith("已")) {
                        executed = true;
                    }
                    Map<String, Object> toolMsg = new LinkedHashMap<>();
                    toolMsg.put("role", "tool");
                    toolMsg.put("tool_call_id", callId);
                    toolMsg.put("content", result);
                    messages.add(toolMsg);
                }
            }

            if (executed || !ACTION_CLAIM.matcher(content).find()) {
                log.info("[助手调试] 判定通过 executed={} content={}", executed, content);
                appendExecutedToMessages(messages, content);
                return content;
            }
            log.warn("[助手调试] 判定为编造，重试 executed={} content={}", executed, content);

            // 声称了操作但没真正执行（没调工具，或调了但工具返回失败）→ 纠正后重试
            messages.add(Map.of("role", "system", "content",
                    "你的上一条回复声称执行了设备操作，但本轮没有任何一次成功的工具执行"
                    + "（工具要么没被调用，要么返回了失败/离线信息），这是编造。"
                    + "请重新回答：要操作设备就必须调用工具并确认工具返回了成功；"
                    +                     "无法操作（如设备离线、设备不存在）就如实说明原因，不要声称已执行。"));
        }
        // 模型连续两轮编造也没救回来：Java 侧按意愿对照表直接执行，保证演示指令稳定生效
        String fuzzy = fuzzyIntentReply(userId, question);
        return fuzzy != null ? fuzzy
                : "我没能完成这个操作。请明确说要打开或关闭哪台设备（例如：打开客厅的灯）。";
    }

    /**
     * Java 侧意愿兜底（2026-11-24）：意愿直答已前移到规则层（tryRuleReply），
     * 这里只处理"模型被判编造后重试仍失败"的残余场景，规则同上。
     * 对照不上返回 null（维持原失败话术，不乱猜）。
     */
    private String fuzzyIntentReply(Long userId, String question) {
        String type = mapIntentType(question);
        if (type == null || looksLikeQuestion(question)) {
            return null;
        }
        Integer power = mapIntentPower(question, type);
        if (power == null) {
            return null;
        }
        log.info("[助手调试] 意图兜底直接执行 type={} power={}", type, power);
        return execDevice(userId, type, power, null);
    }

    /**
     * 判断回复是否在声称执行了设备操作。
     * 要覆盖"已打开""已经为您打开""已帮您关掉"这类插入语气的写法——
     * 模型经常在"已"和动词之间塞"为您/帮您"，正则必须允许这些间隔。
     */
    private static final java.util.regex.Pattern ACTION_CLAIM = java.util.regex.Pattern.compile(
            "已(?:经)?(?:为您|帮你|帮您|为你)*(?:打开|关闭|开启|关掉|切换|调到)|(?:打开|关闭|开启|关掉|切换)了");

    /** 把最终回复记进对话（供校验重试的第二轮参考） */
    private void appendExecutedToMessages(List<Map<String, Object>> messages, String content) {
        messages.add(Map.of("role", "assistant", "content", content));
    }

    /** system prompt：家庭实时状态 + 联动规则 + FAQ + 行为约束 */
    private String buildSystemPrompt(Long userId) {
        StringBuilder sb = new StringBuilder();
        sb.append("你是智慧家居 App 内置的语音助手，用简洁的中文回答用户问题，一次不超过 3 句话。\n");
        sb.append("需要查询或操作设备时必须使用提供的工具，不要编造设备状态。\n");
        sb.append("用户表达了明确意愿时（嫌暗、嫌热、嫌吵、想省事等）直接调用工具执行，不要反问确认。\n");
        sb.append("【意愿→设备对照表（用户没点名设备时按此推断，推断到就直接执行）】\n")
          .append("热 → 打开风扇；冷 → 关闭风扇；暗 → 打开灯；亮得刺眼 → 关闭灯；\n")
          .append("闷/不通风 → 打开风扇；吵 → 关闭蜂鸣器；出门/离家 → 关自动门；回家/进门 → 开自动门。\n");
        sb.append("【安全约束（必须遵守）】\n")
          .append("1. 对照表推断不出对应设备时，简短询问用户想操作什么，绝对不要猜；\n")
          .append("2. 只执行用户要求的操作，严禁顺手执行其他操作（如关灯时不要动门）；\n")
          .append("3. 每次回复只描述真实执行过的操作，没执行工具就说没执行。\n");
        sb.append("只能操作用户名下真实存在的设备；参数校验不通过时如实告知用户。\n\n");
        sb.append("【当前家庭状态（实时）】\n").append(homeStatusText(userId)).append("\n");
        // 实时天气 + 空气质量（2026-11-24 新增）：模型此前不知道天气，答"无法提供"；
        // 数据来自和风代理（后端 10 分钟缓存），取失败不影响助手其他能力
        String weatherText = weatherText();
        if (!weatherText.isEmpty()) {
            sb.append("【当前室外天气（").append("默认城市").append("）】").append(weatherText).append("\n");
        }
        sb.append("【自动模式联动规则】天黑自动开灯；温度偏高自动开风扇；检测到人自动开门；")
          .append("烟雾报警时蜂鸣器鸣响并开风扇（任何模式下都生效）。手动模式不联动。\n");
        sb.append("【常见问题】\n")
          .append("- 切换模式：说\"切换到自动/手动模式\"，或 App 首页顶部模式卡。\n")
          .append("- 烟雾报警：传感器检测到烟雾后，任何模式下蜂鸣器立即鸣响、风扇打开排烟。\n")
          .append("- 设备配网：设备上电后自动连接华为云 IoT 平台，App 端显示在线即可控制。\n");
        return sb.toString();
    }

    /**
     * 拼室外天气一段话（天气 + 空气质量 + 生效预警）。
     * 任何失败都返回空串——天气是锦上添花，不能因为它把整个助手搞挂。
     */
    private String weatherText() {
        try {
            WeatherNowVO now = weatherService.now(null);
            if (now == null) {
                return "";
            }
            StringBuilder sb = new StringBuilder();
            sb.append(now.getCityName() == null ? "" : now.getCityName())
              .append(" ").append(now.getText())
              .append("，").append(now.getTemp()).append("℃")
              .append("（体感 ").append(now.getFeelsLike()).append("℃）")
              .append("，").append(now.getWindDir()).append(" ").append(now.getWindScale()).append("级")
              .append("，湿度 ").append(now.getHumidity()).append("%");
            try {
                WeatherAirVO air = weatherService.air(null);
                if (air != null && air.getCategory() != null) {
                    sb.append("；空气质量").append(air.getCategory())
                      .append("，AQI ").append(air.getAqi())
                      .append("，PM2.5 ").append(air.getPm2p5());
                }
            } catch (Exception ignore) { /* 空气质量拿不到就算了 */ }
            try {
                List<WeatherWarningVO> ws = weatherService.warnings(null);
                if (ws != null && !ws.isEmpty()) {
                    sb.append("；当前生效预警：");
                    for (WeatherWarningVO w : ws) {
                        sb.append("[").append(w.getTitle()).append("] ");
                    }
                }
            } catch (Exception ignore) { /* 预警拿不到就算了 */ }
            return sb.toString();
        } catch (Exception e) {
            log.warn("助手拼装天气上下文失败: {}", e.getMessage());
            return "";
        }
    }

    /** 把数据库里的家庭状态拼成模型能读的文本 */
    private String homeStatusText(Long userId) {        HomeOverviewVO ov = deviceService.overview(userId);
        StringBuilder sb = new StringBuilder();
        sb.append("全屋模式：").append("AUTO".equals(ov.getMode()) ? "自动" : "手动").append("。");
        for (Room room : ov.getRooms()) {
            sb.append("\n房间[").append(room.getName()).append("]：");
            boolean has = false;
            for (DeviceVO d : ov.getDevices()) {
                if (!room.getId().equals(d.getRoomId())) continue;
                has = true;
                JSONObject status = d.getStatus() == null ? new JSONObject()
                        : JSONUtil.parseObj(d.getStatus().toString());
                sb.append(DeviceTypes.NAMES.getOrDefault(d.getType(), d.getType()))
                  .append("(").append(d.getName()).append(")");
                if (status.containsKey("power")) {
                    sb.append("= ").append("on".equals(status.getStr("power")) ? "开" : "关");
                }
                if (status.containsKey("temperature")) {
                    sb.append("，温度 ").append(status.get("temperature")).append("℃");
                }
                if (status.containsKey("humidity")) {
                    sb.append("，湿度 ").append(status.get("humidity")).append("%");
                }
                if (status.containsKey("lux")) {
                    sb.append("，光照 ").append(status.get("lux")).append("lx");
                }
                if (status.containsKey("smoke")) {
                    sb.append("，烟雾 ").append("ALARM".equals(status.getStr("smoke")) ? "报警" : "正常");
                }
                if (status.containsKey("pir")) {
                    sb.append("，").append("ON".equals(status.getStr("pir")) ? "有人" : "无人");
                }
                sb.append("；");
            }
            if (!has) sb.append("无设备");
        }
        // 房间环境（温湿度等级等，取 overview 里已算好的）
        for (RoomEnvironmentVO env : ov.getEnvironments()) {
            if (env.getTemperature() == null && env.getHumidity() == null && env.getLux() == null) continue;
            sb.append("\n[").append(env.getRoomName()).append("] 环境：");
            if (env.getTemperature() != null) sb.append(env.getTemperature()).append("℃(").append(env.getTemperatureLevel()).append(") ");
            if (env.getHumidity() != null) sb.append(env.getHumidity()).append("%RH(").append(env.getHumidityLevel()).append(") ");
            if (env.getLux() != null) sb.append(env.getLux()).append("lx");
        }
        return sb.toString();
    }

    /** 3 个白名单工具的 OpenAI function 定义 */
    private List<Map<String, Object>> buildToolDefinitions() {
        List<Map<String, Object>> tools = new ArrayList<>();

        Map<String, Object> setDevice = new LinkedHashMap<>();
        setDevice.put("type", "object");
        setDevice.put("properties", Map.of(
                "roomName", Map.of("type", "string", "description", "房间名，如 客厅/阳台/厨房；用户没说房间时传空字符串表示全屋找第一台"),
                "deviceType", Map.of("type", "string", "enum", List.of("light", "fan", "gate", "beep"),
                        "description", "设备类型：light灯 fan风扇 gate自动门 beep蜂鸣器"),
                "power", Map.of("type", "string", "enum", List.of("on", "off"), "description", "on开 off关")));
        setDevice.put("required", List.of("deviceType", "power"));
        tools.add(Map.of("type", "function", "function", Map.of(
                "name", "set_device_power",
                "description", "打开或关闭某房间的一台设备",
                "parameters", setDevice)));

        Map<String, Object> setMode = new LinkedHashMap<>();
        setMode.put("type", "object");
        setMode.put("properties", Map.of(
                "mode", Map.of("type", "string", "enum", List.of("AUTO", "MANUAL"),
                        "description", "AUTO自动 MANUAL手动")));
        setMode.put("required", List.of("mode"));
        tools.add(Map.of("type", "function", "function", Map.of(
                "name", "set_home_mode",
                "description", "切换全屋自动/手动模式",
                "parameters", setMode)));

        Map<String, Object> query = new LinkedHashMap<>();
        query.put("type", "object");
        query.put("properties", Map.of(
                "roomName", Map.of("type", "string", "description", "要查询的房间名；空字符串表示全屋")));
        query.put("required", List.of());
        tools.add(Map.of("type", "function", "function", Map.of(
                "name", "query_device_status",
                "description", "查询当前设备状态（开关、温湿度、光照、烟雾、人体感应）",
                "parameters", query)));

        return tools;
    }

    /**
     * 执行模型发起的工具调用。白名单之外一律拒绝；
     * 参数不合法或设备不存在时返回错误说明，让模型向用户解释。
     */
    private String execTool(Long userId, String name, JSONObject args) {
        try {
            switch (name) {
                case "set_device_power": {
                    String type = args.getStr("deviceType", "");
                    String power = args.getStr("power", "");
                    if (!List.of(DeviceTypes.LIGHT, DeviceTypes.FAN, DeviceTypes.GATE, DeviceTypes.BEEP).contains(type)) {
                        return "错误：设备类型 " + type + " 不在可控范围内";
                    }
                    if (!List.of("on", "off").contains(power)) {
                        return "错误：power 只能是 on/off";
                    }
                    String roomName = args.getStr("roomName", "");
                    Room room = roomName.isBlank() ? null : findRoomByName(userId, roomName);
                    if (room == null && !roomName.isBlank()) {
                        return "错误：房间[" + roomName + "]不存在，现有房间：" + roomNames(userId);
                    }
                    Device device = findDevice(userId, room == null ? null : room.getId(), type);
                    if (device == null) {
                        return "错误：没找到" + (room == null ? "" : room.getName()) + "的"
                                + DeviceTypes.NAMES.getOrDefault(type, type);
                    }
                    if (device.getOnline() != null && device.getOnline() == 0) {
                        return "错误：" + device.getName() + "当前离线，无法执行。请告知用户检查设备电源和网络。";
                    }
                    deviceService.control(device.getId(), userId, Map.of("power", power));
                    return "已" + ("on".equals(power) ? "打开" : "关闭")
                            + prettyDeviceName(roomNameOf(userId, device.getRoomId()), device.getName());
                }
                case "set_home_mode": {
                    String mode = args.getStr("mode", "");
                    if (!List.of("AUTO", "MANUAL").contains(mode)) {
                        return "错误：mode 只能是 AUTO/MANUAL";
                    }
                    deviceService.setMode(mode, userId);
                    return "已切换到" + ("AUTO".equals(mode) ? "自动" : "手动") + "模式";
                }
                case "query_device_status": {
                    String roomName = args.getStr("roomName", "");
                    if (roomName.isBlank()) {
                        return homeStatusText(userId);
                    }
                    Room room = findRoomByName(userId, roomName);
                    if (room == null) {
                        return "错误：房间[" + roomName + "]不存在，现有房间：" + roomNames(userId);
                    }
                    StringBuilder sb = new StringBuilder("房间[").append(room.getName()).append("]设备状态：");
                    List<Device> devices = devicesOf(userId);
                    boolean has = false;
                    for (Device d : devices) {
                        if (!room.getId().equals(d.getRoomId())) continue;
                        has = true;
                        sb.append("\n").append(d.getName()).append("(").append(d.getType()).append(") ");
                        if (d.getOnline() != null && d.getOnline() == 0) {
                            sb.append("离线");
                        } else {
                            sb.append(d.getStatus());
                        }
                    }
                    return has ? sb.toString() : "该房间没有设备";
                }
                default:
                    return "错误：工具 " + name + " 不在白名单内，已拒绝执行";
            }
        } catch (BizException e) {
            return "执行失败：" + e.getMessage();
        } catch (Exception e) {
            log.warn("工具执行异常 name={} args={}", name, args, e);
            return "执行失败：服务内部错误";
        }
    }

    // ========================= 数据小工具 =========================

    private List<Room> userRooms(Long userId) {
        return roomMapper.selectList(new LambdaQueryWrapper<Room>().eq(Room::getUserId, userId));
    }

    private List<Device> devicesOf(Long userId) {
        List<Long> roomIds = userRooms(userId).stream().map(Room::getId).toList();
        if (roomIds.isEmpty()) return List.of();
        return deviceMapper.selectList(new LambdaQueryWrapper<Device>().in(Device::getRoomId, roomIds));
    }

    private Room findRoomByName(Long userId, String name) {
        for (Room room : userRooms(userId)) {
            if (room.getName().equals(name) || room.getName().contains(name) || name.contains(room.getName())) {
                return room;
            }
        }
        return null;
    }

    /** 找某房间的某类型设备（可指定房间；type 为 null 时返回 null） */
    private Device findDevice(Long userId, Long roomId, String type) {
        for (Device d : devicesOf(userId)) {
            if (d.getType().equals(type) && (roomId == null || roomId.equals(d.getRoomId()))) {
                return d;
            }
        }
        return null;
    }

    private String roomNameOf(Long userId, Long roomId) {
        for (Room room : userRooms(userId)) {
            if (room.getId().equals(roomId)) return room.getName();
        }
        return "";
    }

    private String roomNames(Long userId) {
        StringBuilder sb = new StringBuilder();
        for (Room room : userRooms(userId)) {
            if (sb.length() > 0) sb.append("、");
            sb.append(room.getName());
        }
        return sb.toString();
    }

    /** 设备名拼房间名：设备名里已带房间（如"客厅灯"）就不重复 */
    private String prettyDeviceName(String roomName, String deviceName) {
        if (roomName != null && !roomName.isBlank() && !deviceName.contains(roomName)) {
            return roomName + "的" + deviceName;
        }
        return deviceName;
    }

    private void appendHistory(Long userId, String role, String content) {
        List<Map<String, String>> list = history.computeIfAbsent(userId, k -> new ArrayList<>());
        list.add(Map.of("role", role, "content", content));
        while (list.size() > MAX_HISTORY_MESSAGES) {
            list.remove(0);
        }
    }

    /** 模型不可用 / 未配置 Key 时的固定话术 */
    private static final String FALLBACK_REPLY =
            "助手暂时不可用，您可以直接在房间页控制设备。这些我可以直接回答：\n"
            + "· 切换模式：说\"切换到自动模式 / 手动模式\"\n"
            + "· 控制设备：说\"打开客厅的灯\"\"关闭风扇\"这类指令\n"
            + "· 烟雾报警：检测到烟雾后任何模式下蜂鸣器都会鸣响、风扇打开排烟\n"
            + "· 自动模式联动：天黑开灯、温度偏高开风扇、来人开门。";
}
