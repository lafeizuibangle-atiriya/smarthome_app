package com.smarthome.service.impl;

import cn.hutool.json.JSONConfig;
import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.smarthome.common.BizException;
import com.smarthome.common.DeviceTypes;
import com.smarthome.common.PageVO;
import com.smarthome.dto.DeviceAddDTO;
import com.smarthome.dto.RoomEnvDTO;
import com.smarthome.entity.Device;
import com.smarthome.entity.DeviceLog;
import com.smarthome.entity.Room;
import com.smarthome.entity.RoomEnvironment;
import com.smarthome.entity.SystemConfig;
import com.smarthome.mapper.DeviceLogMapper;
import com.smarthome.mapper.DeviceMapper;
import com.smarthome.mapper.RoomEnvironmentMapper;
import com.smarthome.mapper.RoomMapper;
import com.smarthome.mapper.SystemConfigMapper;
import com.smarthome.service.DeviceService;
import com.smarthome.service.HuaweiIoTClient;
import com.smarthome.service.HuaweiSyncService;
import com.smarthome.vo.DeviceVO;
import com.smarthome.vo.HomeOverviewVO;
import com.smarthome.vo.RoomEnvironmentVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceServiceImpl implements DeviceService {

    private final RoomMapper roomMapper;
    private final DeviceMapper deviceMapper;
    private final DeviceLogMapper deviceLogMapper;
    private final RoomEnvironmentMapper roomEnvironmentMapper;   // 环境监测（2026-09 新增）
    private final HuaweiIoTClient huaweiIoTClient;               // 华为云下行转发（2026-11-19 新增）
    private final SystemConfigMapper systemConfigMapper;         // 全屋模式配置（2026-11-20 新增）

    /** 环境更新时间展示格式：2026-09-20 10:31:05 */
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /** 唯一有传感器的房间名：硬件的温湿度 + 光照传感器按约定归属"阳台"（2026-11-19 对齐硬件） */
    private static final String ENV_ROOM_NAME = "阳台";

    /**
     * 只读字段：由后端或"硬件上报"产生，前端下发一律丢弃。
     * 【为什么要在后端拦】前端代码是可以被绕过的（接口直调），
     * 只要这些字段能被下发，伪造传感器数据就只是改一个 JSON 的事。
     */
    private static final Set<String> READONLY_KEYS = Set.of(
            "smoke",                   // 烟雾传感器：浓度（硬件 SmokeStatus 同步）
            "alarm",                   // 烟雾传感器：报警位（硬件 SmokeStatus 同步）
            "battery",                 // 烟雾传感器：电量（设备上报）
            "temperature", "humidity", "lux",   // 环境检测：硬件 SHT30/BH1750 上报
            "present");                // 人体感应：硬件 PIR_Status 同步

    /** 灯色温档位白名单（暖光 / 自然 / 冷白） */
    private static final Set<Integer> COLOR_TEMPS = Set.of(2700, 4000, 6500);

    /** "HH:mm" 时刻格式 */
    private static final DateTimeFormatter HM_FMT = DateTimeFormatter.ofPattern("HH:mm");

    // ==================== 设备 ====================

    @Override
    public List<DeviceVO> listByRoom(Long roomId, Long userId) {
        checkRoomOwner(roomId, userId);
        return deviceMapper.selectList(
                        new LambdaQueryWrapper<Device>().eq(Device::getRoomId, roomId))
                .stream().map(this::toVO).collect(Collectors.toList());
    }

    @Override
    public DeviceVO detail(Long deviceId, Long userId) {
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        return toVO(device);
    }

    @Override
    public List<DeviceLog> logs(Long deviceId, Long userId) {
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        return deviceLogMapper.selectList(new LambdaQueryWrapper<DeviceLog>()
                .eq(DeviceLog::getDeviceId, deviceId)
                .orderByDesc(DeviceLog::getCreateTime));
    }

    /**
     * 设备操作日志分页版（2026-11-23 后端增强）。
     * 物理分页：分页插件在 SQL 上拼 LIMIT，不查全表；pageSize 上限 50 防恶意大页。
     */
    @Override
    public PageVO<DeviceLog> logsPage(Long deviceId, Long userId, int pageNum, int pageSize) {
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        if (pageNum < 1) pageNum = 1;
        pageSize = Math.min(Math.max(pageSize, 1), 50);
        Page<DeviceLog> page = deviceLogMapper.selectPage(
                new Page<>(pageNum, pageSize),
                new LambdaQueryWrapper<DeviceLog>()
                        .eq(DeviceLog::getDeviceId, deviceId)
                        .orderByDesc(DeviceLog::getCreateTime));
        return PageVO.of(page.getRecords(), page.getTotal(), page.getCurrent(), page.getSize());
    }

    /**
     * 首页总览：一次请求返回首页需要的一切。
     * environments 与 rooms 等长同序，前端用同一个下标就能取到"当前房间"的环境。
     */
    @Override
    public HomeOverviewVO overview(Long userId) {
        HomeOverviewVO vo = new HomeOverviewVO();
        vo.setHomeName("我的家");

        List<Room> rooms = roomMapper.selectList(
                new LambdaQueryWrapper<Room>().eq(Room::getUserId, userId).orderByAsc(Room::getSort));
        vo.setRooms(rooms);

        if (rooms.isEmpty()) {
            vo.setDevices(new ArrayList<>());
            vo.setEnvironments(new ArrayList<>());
            vo.setAlarmCount(0);
            return vo;
        }

        List<Long> roomIds = rooms.stream().map(Room::getId).collect(Collectors.toList());
        List<Device> devices = deviceMapper.selectList(
                new LambdaQueryWrapper<Device>().in(Device::getRoomId, roomIds));
        vo.setDevices(devices.stream().map(this::toVO).collect(Collectors.toList()));

        List<RoomEnvironmentVO> envs = new ArrayList<>();
        for (Room room : rooms) {
            envs.add(toEnvVO(room, loadOrInit(room)));
        }
        vo.setEnvironments(envs);
        vo.setAlarmCount(0);        // 【2026-11-19 对齐硬件】环境告警走烟雾传感器设备卡片，这里恒为 0
        vo.setMode(loadMode());     // 全屋自动/手动模式（硬件 ModeStatus 同步）
        log.info("[环境监测] 首页总览｜用户#{} 房间{}个", userId, rooms.size());
        return vo;
    }

    /**
     * 全屋模式切换（2026-11-20 新增）：App → 后端 → 华为云 → 硬件。
     * AUTO = 自动模式（光控灯 / 温控风扇 / PIR 控门 / 烟雾报警联动蜂鸣器+风扇）；
     * MANUAL = 手动模式（一切由 App 控制，烟雾报警仍然生效——安全优先）。
     * 先下发命令再乐观写库：设备执行成功后 ModeStatus 会上报回来，
     * HuaweiSyncService 把库里的值对齐为硬件真实状态。
     */
    @Override
    public String setMode(String mode, Long userId) {
        if (!"AUTO".equalsIgnoreCase(mode) && !"MANUAL".equalsIgnoreCase(mode)) {
            throw new BizException("模式只支持 AUTO / MANUAL");
        }
        boolean auto = "AUTO".equalsIgnoreCase(mode);
        boolean sent = huaweiIoTClient.sendModeCommand(auto);
        if (!sent) {
            throw new BizException("模式切换命令下发失败，请检查设备是否在线");
        }

        // 下发成功后先写入期望值，等设备 ModeStatus 上报回来确认
        SystemConfig cfg = systemConfigMapper.selectOne(new LambdaQueryWrapper<SystemConfig>()
                .eq(SystemConfig::getConfigKey, HuaweiSyncService.CONFIG_KEY_MODE));
        String value = auto ? "AUTO" : "MANUAL";
        if (cfg == null) {
            cfg = new SystemConfig();
            cfg.setConfigKey(HuaweiSyncService.CONFIG_KEY_MODE);
            cfg.setConfigValue(value);
            systemConfigMapper.insert(cfg);
        } else {
            cfg.setConfigValue(value);
            systemConfigMapper.updateById(cfg);
        }
        log.info("[全屋模式] 用户#{} 切换为{}模式", userId, auto ? "自动" : "手动");
        return value;
    }

    /** 读全屋模式，没有记录时默认 AUTO（硬件上电默认也是自动模式） */
    private String loadMode() {
        SystemConfig cfg = systemConfigMapper.selectOne(new LambdaQueryWrapper<SystemConfig>()
                .eq(SystemConfig::getConfigKey, HuaweiSyncService.CONFIG_KEY_MODE));
        return cfg == null ? "AUTO" : cfg.getConfigValue();
    }

    /**
     * 控制设备：合并状态 JSON + 写操作日志，同一事务。
     * 不同设备属性不同，所以用 Map 合并而不是固定字段。
     *
     * <p>【2026-11-19 对齐硬件】可控设备的开关语义全部统一为 power（on/off）：
     * 灯/风扇/自动门/蜂鸣器直接发 power；自动门 power=on 即开门。
     * 只读传感器（env_sensor / pir_sensor / smoke_sensor 的数值）不提供控制。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public DeviceVO control(Long deviceId, Long userId, Map<String, Object> action) {
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        if (action == null || action.isEmpty()) throw new BizException("控制指令不能为空");

        // 统一清洗：剥离只读字段（由后端/传感器维护）+ 校验取值，越界直接报错。
        Map<String, Object> safe = sanitizeAction(action, device.getType());
        if (safe.isEmpty()) {
            throw new BizException("没有可执行的控制项");
        }

        Map<String, Object> status = JSONUtil.parseObj(device.getStatus());
        status.putAll(safe);                                    // 旧状态 + 本次动作
        device.setStatus(JSONUtil.toJsonStr(status));
        deviceMapper.updateById(device);

        DeviceLog deviceLog = new DeviceLog();
        deviceLog.setDeviceId(deviceId);
        deviceLog.setUserId(userId);
        deviceLog.setAction(describeAction(device.getType(), safe));
        deviceLogMapper.insert(deviceLog);

        // 【2026-11-19 新增】下行转发：App → 后端 → 华为云 → 硬件。
        // 只转发 power（ON/OFF），亮度/色温等本地展示字段不转发。
        // 云端未启用时静默跳过（纯模拟模式）；下发失败不影响本地状态——
        // 硬件 3 秒上报一次真实状态，HuaweiSyncTask 会把偏离纠正回来。
        if (safe.containsKey("power")) {
            boolean on = "on".equals(String.valueOf(safe.get("power")));
            huaweiIoTClient.sendPowerCommand(device.getType(), on);
        }

        log.info("[设备控制] 用户#{} 控制设备#{}-{}({}) 指令{} → 新状态{}",
                userId, device.getId(), device.getName(), device.getType(),
                JSONUtil.toJsonStr(safe), JSONUtil.toJsonStr(status));
        return toVO(device);
    }

    /**
     * 校验并规范化一次控制指令。返回的是**真正会被写进 status 的字段**。
     *
     * <p>三步：① 丢掉只读字段；② 枚举/数值字段必须在合法区间，越界抛异常；
     * ③ power 直接放行（五种设备的开关都是 power on/off）。
     */
    private Map<String, Object> sanitizeAction(Map<String, Object> action, String deviceType) {
        Map<String, Object> clean = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : action.entrySet()) {
            String key = entry.getKey();
            Object val = entry.getValue();
            if (val == null) {
                continue;
            }
            if (READONLY_KEYS.contains(key)) {
                log.warn("[设备控制] 忽略只读字段 {}（由后端/设备上报维护，不接受下发）", key);
                continue;
            }

            if ("brightness".equals(key)) {
                clean.put(key, intRange(key, val, 1, 100));
            } else if ("colorTemp".equals(key)) {
                int ct = toInt(key, val);
                if (!COLOR_TEMPS.contains(ct)) {
                    throw new BizException("色温只支持 2700 / 4000 / 6500 K");
                }
                clean.put(key, ct);
            } else if ("timerOn".equals(key) || "timerOff".equals(key)) {
                clean.put(key, timeOrEmpty(key, val));
            } else {
                clean.put(key, val);        // power 等其余字段放行，保持向后兼容
            }
        }
        return clean;
    }

    // ==================== 操作日志中文化 ====================

    /** 控制字段的中文描述顺序（日志按这个顺序拼接，稳定可读） */
    private static final List<String> ACTION_KEY_ORDER = List.of(
            "power", "brightness", "colorTemp", "timerOn", "timerOff");

    /**
     * 把一次控制指令翻译成简洁中文，如"开机，亮度调至80%"。
     * 【为什么在后端翻】device_log 是给人看的操作记录，存 JSON 前端还得再翻译一遍；
     * 直接在写入时翻好，App / 管理端 / 数据库导出看到的都是同一份人话。
     */
    private String describeAction(String type, Map<String, Object> safe) {
        List<String> parts = new ArrayList<>();
        for (String key : ACTION_KEY_ORDER) {
            Object val = safe.get(key);
            if (val == null) {
                continue;
            }
            String phrase = describeOne(type, key, val);
            if (!phrase.isEmpty()) {
                parts.add(phrase);
            }
        }
        for (Map.Entry<String, Object> e : safe.entrySet()) {
            // 兜底：不在顺序表里的未知字段，按 key=value 原样列出（保持向后兼容）
            if (!ACTION_KEY_ORDER.contains(e.getKey()) && e.getValue() != null) {
                parts.add(e.getKey() + "=" + e.getValue());
            }
        }
        return parts.isEmpty() ? "控制设备" : String.join("，", parts);
    }

    /** 单个字段的中文文案 */
    private String describeOne(String type, String key, Object val) {
        int n = (val instanceof Number) ? ((Number) val).intValue() : Integer.MIN_VALUE;
        String s = String.valueOf(val);
        switch (key) {
            case "power":
                // 自动门的开关语义：on = 开门
                if (DeviceTypes.GATE.equals(type)) {
                    return "on".equals(s) ? "开门" : "关门";
                }
                return "on".equals(s) ? "开机" : "关机";
            case "brightness": return "亮度调至" + n + "%";
            case "colorTemp":  return "色温调至" + colorTempName(n);
            case "timerOn":    return s.isEmpty() ? "取消定时开机" : "定时开机设为每天 " + s;
            case "timerOff":   return s.isEmpty() ? "取消定时关机" : "定时关机设为每天 " + s;
            default:           return "";
        }
    }

    /** 色温数值 → 中文档位名 */
    private String colorTempName(int ct) {
        if (ct == 2700) return "暖光 2700K";
        if (ct == 4000) return "自然光 4000K";
        if (ct == 6500) return "冷白光 6500K";
        return ct + "K";
    }

    /** 取整（兼容 JSON 数字与字符串） */
    private int toInt(String key, Object val) {
        if (val instanceof Number) {
            return ((Number) val).intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(val).trim());
        } catch (NumberFormatException e) {
            throw new BizException("字段 " + key + " 必须是整数");
        }
    }

    /** 取整 + 区间校验，越界直接报错（宁可报错也不悄悄夹取，问题能尽早暴露） */
    private int intRange(String key, Object val, int min, int max) {
        int n = toInt(key, val);
        if (n < min || n > max) {
            throw new BizException("字段 " + key + " 超出范围（" + min + "~" + max + "）：" + n);
        }
        return n;
    }

    /** 时刻字段：空串 = 取消；否则必须是 "HH:mm" */
    private String timeOrEmpty(String key, Object val) {
        String s = val == null ? "" : String.valueOf(val).trim();
        if (s.isEmpty()) {
            return "";
        }
        if (!s.matches("^([01]\\d|2[0-3]):[0-5]\\d$")) {
            throw new BizException("字段 " + key + " 格式应为 HH:mm（如 07:30）");
        }
        return s;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void add(DeviceAddDTO dto, Long userId) {
        checkRoomOwner(dto.getRoomId(), userId);
        // 类型必须是字典里登记过的 —— 拼错类型在这里就被拦下，而不是等到前端渲染一脸懵
        if (!DeviceTypes.NAMES.containsKey(dto.getType())) {
            throw new BizException("不支持的设备类型：" + dto.getType());
        }

        Device device = new Device();
        device.setRoomId(dto.getRoomId());
        device.setName(dto.getName());
        device.setType(dto.getType());
        device.setOnline(1);
        device.setStatus(DeviceTypes.defaultStatus(dto.getType()));
        deviceMapper.insert(device);
        log.info("[设备管理] 用户#{} 在房间#{} 添加设备#{}-{}({})",
                userId, dto.getRoomId(), device.getId(), device.getName(), device.getType());
    }

    @Override
    public void rename(Long deviceId, Long userId, String name) {
        if (name == null || name.isEmpty()) throw new BizException("设备名不能为空");
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        device.setName(name);
        deviceMapper.updateById(device);
        log.info("[设备管理] 用户#{} 重命名设备#{}-{} → {}", userId, deviceId, device.getName(), name);
    }

    @Override
    public void remove(Long deviceId, Long userId) {
        Device device = deviceMapper.selectById(deviceId);
        if (device == null) throw new BizException("设备不存在");
        checkRoomOwner(device.getRoomId(), userId);
        deviceMapper.deleteById(deviceId);
        log.info("[设备管理] 用户#{} 删除设备#{}-{}", userId, deviceId, device.getName());
    }

    // ==================== 房间（与设备/环境同域） ====================

    @Override
    public List<Room> roomList(Long userId) {
        return roomMapper.selectList(
                new LambdaQueryWrapper<Room>().eq(Room::getUserId, userId).orderByAsc(Room::getSort));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void addRoom(String name, Long userId) {
        if (name == null || name.isEmpty()) throw new BizException("房间名不能为空");
        long count = roomMapper.selectCount(new LambdaQueryWrapper<Room>().eq(Room::getUserId, userId));
        Room room = new Room();
        room.setUserId(userId);
        room.setName(name);
        room.setSort((int) count + 1);
        roomMapper.insert(room);
        loadOrInit(room);   // 顺手初始化一条环境记录，首页面板不空白
        log.info("[设备管理] 用户#{} 新增房间#{}-{}(sort={})", userId, room.getId(), name, room.getSort());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void renameRoom(Long roomId, Long userId, String name) {
        if (name == null || name.isEmpty()) throw new BizException("房间名不能为空");
        Room room = checkRoomOwner(roomId, userId);
        room.setName(name);
        roomMapper.updateById(room);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void removeRoom(Long roomId, Long userId) {
        Room room = checkRoomOwner(roomId, userId);
        long deviceCount = deviceMapper.selectCount(
                new LambdaQueryWrapper<Device>().eq(Device::getRoomId, roomId));
        if (deviceCount > 0) throw new BizException("请先移除房间内的设备");
        roomEnvironmentMapper.delete(new LambdaQueryWrapper<RoomEnvironment>()
                .eq(RoomEnvironment::getRoomId, roomId));
        roomMapper.deleteById(roomId);
        log.info("[设备管理] 用户#{} 删除房间#{}-{}", userId, roomId, room.getName());
    }

    // ==================== 环境监测（2026-11-19 对齐硬件：温湿度 + 光照，仅阳台） ====================

    @Override
    public RoomEnvironmentVO environment(Long roomId, Long userId) {
        Room room = checkRoomOwner(roomId, userId);
        RoomEnvironmentVO vo = toEnvVO(room, loadOrInit(room));
        log.info("[环境监测] 查询环境｜房间#{}-{}", room.getId(), room.getName());
        return vo;
    }

    /**
     * 手动"立即刷新"：真实数据由华为云 AMQP 推送持续写入，这里直接返回库里的最新值。
     * 保留接口是因为前端有"立即刷新"按钮，语义从"采样"变成了"读最新上报"。
     */
    @Override
    public RoomEnvironmentVO refreshEnvironment(Long roomId, Long userId, RoomEnvDTO dto) {
        Room room = checkRoomOwner(roomId, userId);
        RoomEnvironmentVO vo = toEnvVO(room, loadOrInit(room));
        log.info("[环境监测] 手动刷新｜房间#{}-{} 操作人#{}", room.getId(), room.getName(), userId);
        return vo;
    }

    @Override
    public List<Map<String, String>> envMetrics() {
        return List.of(
                Map.of("key", "temperature", "name", "温度", "unit", "℃"),
                Map.of("key", "humidity", "name", "湿度", "unit", "%"),
                Map.of("key", "lux", "name", "光照强度", "unit", "lx")
        );
    }

    @Override
    public List<Map<String, Object>> types() {
        // 字典收敛到 DeviceTypes（7 种：5 可控 + 2 只读，与硬件侧一一对应），这里只负责"翻译成接口格式"。
        List<Map<String, Object>> list = new ArrayList<>();
        for (String type : DeviceTypes.ALL) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("type", type);
            item.put("name", DeviceTypes.NAMES.get(type));
            list.add(item);
        }
        return list;
    }

    // ==================== 通用设备定时开关 ====================

    /**
     * 定时任务调用（每分钟）：扫描所有设备的 timerOn / timerOff，
     * 与当前时刻（HH:mm）相等就执行对应动作。返回触发台数。
     *
     * <p>【幂等性】判断条件是"HH:mm 恰好相等"，本任务每分钟只跑一次，
     * 同一分钟不会被重复触发；定时是"每天重复"的（到点后不清空），
     * 符合真实产品里"每天 07:00 开灯"的直觉。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public int runDeviceTimers() {
        String nowHm = LocalTime.now().format(HM_FMT);
        List<Device> devices = deviceMapper.selectList(null);
        if (devices.isEmpty()) {
            return 0;
        }
        // 设备表本身不存 userId（归属看房间），写操作日志时要用房间的主人
        Map<Long, Long> roomOwner = roomMapper.selectList(null).stream()
                .collect(Collectors.toMap(Room::getId, Room::getUserId, (a, b) -> a));

        int fired = 0;
        for (Device dev : devices) {
            Map<String, Object> status = JSONUtil.parseObj(dev.getStatus());
            boolean onDue = nowHm.equals(safeStr(status.get("timerOn")));
            boolean offDue = nowHm.equals(safeStr(status.get("timerOff")));
            if (!onDue && !offDue) {
                continue;
            }
            // 两个定时撞在同一分钟时关机优先：关比开安全（不会让灯/风扇一直开着）
            boolean turnOn = onDue && !offDue;

            // 五种设备的"开/关"语义统一为 power（自动门 on = 开门）
            status.put("power", turnOn ? "on" : "off");
            dev.setStatus(JSONUtil.toJsonStr(status));
            deviceMapper.updateById(dev);

            // 【2026-11-19 新增】定时也转发云端命令：到点真实硬件跟着动作，
            // 不再出现"App 显示关了、硬件还开着"的假同步。只读传感器没有
            // 开关语义，sendPowerCommand 内部按类型返回 false，静默跳过。
            huaweiIoTClient.sendPowerCommand(dev.getType(), turnOn);

            DeviceLog deviceLog = new DeviceLog();
            deviceLog.setDeviceId(dev.getId());
            deviceLog.setUserId(roomOwner.getOrDefault(dev.getRoomId(), 0L));
            deviceLog.setAction(turnOn ? "到点自动开机" : "到点自动关机");
            deviceLogMapper.insert(deviceLog);

            log.info("[设备定时] {}｜设备#{}-{}({}) 到点{} → 新状态{}",
                    turnOn ? "定时开机" : "定时关机", dev.getId(), dev.getName(),
                    dev.getType(), nowHm, JSONUtil.toJsonStr(status));
            fired++;
        }
        return fired;
    }

    /** null 安全的字符串取值，用于比较时刻 / 开关状态 */
    private String safeStr(Object o) {
        return o == null ? "" : o.toString();
    }

    // ==================== 环境监测私有辅助 ====================

    /**
     * 取房间的环境记录：只有"阳台"有传感器，其余房间建一条全 null 的空记录
     * （前端据此显示"暂无环境检测"）。数值本身由华为云上报同步（HuaweiSyncService）。
     */
    private RoomEnvironment loadOrInit(Room room) {
        RoomEnvironment env = roomEnvironmentMapper.selectOne(
                new LambdaQueryWrapper<RoomEnvironment>().eq(RoomEnvironment::getRoomId, room.getId()));
        if (env != null) {
            return env;
        }
        env = new RoomEnvironment();
        env.setRoomId(room.getId());
        boolean hasSensor = ENV_ROOM_NAME.equals(room.getName());
        if (hasSensor) {
            // 给一组占位初值，真实值等硬件上报后由同步逻辑覆盖
            env.setTemperature(0.0);
            env.setHumidity(0);
            env.setLux(0.0);
        }
        env.setUpdateTime(hasSensor ? LocalDateTime.now() : null);
        roomEnvironmentMapper.insert(env);
        log.info("[环境监测] 初始化房间环境｜房间#{}-{} 传感器={}",
                room.getId(), room.getName(), hasSensor ? "有（阳台）" : "无");
        return env;
    }

    /** entity → VO：把原始数值翻译成"人能看懂"的等级文案；无传感器的房间三项为 null */
    private RoomEnvironmentVO toEnvVO(Room room, RoomEnvironment env) {
        RoomEnvironmentVO vo = new RoomEnvironmentVO();
        vo.setRoomId(env.getRoomId());
        vo.setRoomName(room.getName());
        boolean hasSensor = env.getTemperature() != null || env.getHumidity() != null || env.getLux() != null;
        if (hasSensor) {
            vo.setTemperature(env.getTemperature());
            vo.setTemperatureLevel(tempLevel(env.getTemperature()));
            vo.setHumidity(env.getHumidity());
            vo.setHumidityLevel(humidityLevel(env.getHumidity()));
            vo.setLux(env.getLux());
            vo.setUpdateTime(env.getUpdateTime() == null ? "" : env.getUpdateTime().format(TIME_FMT));
        }
        vo.setAlarmCount(0);
        return vo;
    }

    private String tempLevel(Double t) {
        if (t == null) return "—";
        if (t < 18) return "偏冷";
        if (t > 28) return "偏热";
        return "舒适";
    }

    private String humidityLevel(Integer h) {
        if (h == null) return "—";
        if (h < 30) return "干燥";
        if (h > 70) return "潮湿";
        return "舒适";
    }

    // ==================== 私有辅助：权限 ====================

    /** 校验房间归属，实现数据隔离；返回房间对象方便调用方复用 */
    private Room checkRoomOwner(Long roomId, Long userId) {
        Room room = roomMapper.selectById(roomId);
        if (room == null) throw new BizException("房间不存在");
        if (!room.getUserId().equals(userId)) throw new BizException("无权操作该房间");
        return room;
    }

    private DeviceVO toVO(Device device) {
        DeviceVO vo = new DeviceVO();
        vo.setId(device.getId());
        vo.setRoomId(device.getRoomId());
        vo.setName(device.getName());
        vo.setType(device.getType());
        vo.setOnline(device.getOnline());
        // ignoreNullValue：status 里的 null 键（如环境检测未上报时）解析时直接丢掉，
        // 避免 Hutool 的 JSONNull 对象传给 Jackson 序列化时报错
        vo.setStatus(JSONUtil.parseObj(device.getStatus(),
                JSONConfig.create().setIgnoreNullValue(true)));
        return vo;
    }
}
