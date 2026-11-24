package com.smarthome.service;

import cn.hutool.http.HttpRequest;
import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * 大模型 API 客户端（2026-11-23 智能助手新增）。
 *
 * <p>走 OpenAI 兼容的 chat/completions 协议（智谱 GLM-4-Flash / DeepSeek / 通义均兼容），
 * 用 Hutool 的 HttpRequest 直接发 HTTP，不引入任何 SDK。
 * API Key 在 application.yml 的 llm.api.key 配置；留空时 enabled() 返回 false，
 * AssistantService 自动退化为"关键词直答 + FAQ 兜底"，接口照常可用。
 */
@Component
public class LlmClient {

    @Value("${llm.api.url}")
    private String url;

    @Value("${llm.api.key}")
    private String apiKey;

    @Value("${llm.api.model}")
    private String model;

    @Value("${llm.api.timeout-seconds:20}")
    private int timeoutSeconds;

    /**
     * 启动时打一条启用状态——2026-11-24 排查发现 key 走环境变量后，
     * 环境变量没注入时助手会静默退化成兜底模式，没日志根本看不出原因。
     */
    @jakarta.annotation.PostConstruct
    void logStartupState() {
        if (enabled()) {
            org.slf4j.LoggerFactory.getLogger(LlmClient.class)
                    .info("[智能助手] LLM 已启用，model={}（key 来自环境变量 LLM_API_KEY）", model);
        } else {
            org.slf4j.LoggerFactory.getLogger(LlmClient.class)
                    .warn("[智能助手] 未配置 LLM_API_KEY 环境变量，助手退化为纯规则+FAQ 兜底模式，"
                            + "自然语言控制设备不可用");
        }
    }

    /** 是否已配置 API Key（决定走大模型还是纯规则） */
    public boolean enabled() {
        return apiKey != null && !apiKey.isBlank();
    }

    public String model() {
        return model;
    }

    /**
     * 发起一次对话请求，返回模型生成的 assistant 消息体。
     * 消息体可能是普通文本（content），也可能带 tool_calls（要求调用工具）。
     *
     * @param messages OpenAI 格式消息列表（role/content，含 system 与历史）
     * @param tools    工具定义列表（OpenAI function 格式），可为 null
     */
    public JSONObject chatCompletion(List<Map<String, Object>> messages,
                                     List<Map<String, Object>> tools) {
        JSONObject body = new JSONObject();
        body.set("model", model);
        body.set("messages", messages);
        body.set("temperature", 0.3);          // 控制类场景要稳定，调低随机性
        if (tools != null && !tools.isEmpty()) {
            body.set("tools", tools);
            body.set("tool_choice", "auto");
        }

        String resp = HttpRequest.post(url)
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .body(body.toString())
                .timeout(timeoutSeconds * 1000)
                .execute()
                .body();

        JSONObject respJson = JSONUtil.parseObj(resp);
        JSONObject error = respJson.getJSONObject("error");
        if (error != null) {
            throw new IllegalStateException("大模型接口返回错误: " + error.getStr("message", resp));
        }
        JSONArray choices = respJson.getJSONArray("choices");
        if (choices == null || choices.isEmpty()) {
            throw new IllegalStateException("大模型接口返回异常: " + resp);
        }
        return choices.getJSONObject(0).getJSONObject("message");
    }
}
