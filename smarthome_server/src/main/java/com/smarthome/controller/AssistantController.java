package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.service.AssistantService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 智能助手接口（2026-11-23 新增）。
 * 走登录拦截器，token 与其他 /api 接口一致。
 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class AssistantController {

    private final AssistantService assistantService;

    /**
     * 对话入口：body {"question": "帮我关掉客厅的灯"}
     * 返回 {reply: 助手回复, source: rule(关键词直答)/llm(大模型)/fallback(兜底)}
     */
    @PostMapping("/assistant/chat")
    public Result<Map<String, Object>> chat(@RequestBody Map<String, Object> body,
                                            HttpServletRequest request) {
        Object q = body == null ? null : body.get("question");
        if (q == null || String.valueOf(q).isBlank()) {
            return Result.error(400, "问题内容不能为空");
        }
        return Result.ok(assistantService.chat(
                (Long) request.getAttribute("userId"), String.valueOf(q)));
    }
}
