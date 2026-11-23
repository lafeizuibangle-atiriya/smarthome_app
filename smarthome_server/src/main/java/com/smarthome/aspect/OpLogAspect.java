package com.smarthome.aspect;

import com.smarthome.entity.OperationLog;
import com.smarthome.service.OperationLogService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.WebUtils;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * 操作日志切面（2026-09 新增）。
 *
 * <p>拦截所有 @RestController 的写操作（POST / PUT / DELETE），
 * 自动把"谁、在哪个模块、做了什么、请求明细"落到 operation_log 表，
 * 同时在控制台打一行 {@code [操作日志] 用户#1 设备 · 控制设备 {...}}。
 *
 * <p>设计要点：
 * <ul>
 *   <li>明细从 ContentCachingRequestWrapper 读已缓存的请求体，不重复消费流；</li>
 *   <li>password 等敏感字段做脱敏（替换为 ***），整条明细截断到 200 字；</li>
 *   <li>整段 try-catch 兜底——日志写失败绝不能影响主业务；</li>
 *   <li>只有写操作才记，GET 等查询不记，避免日志爆炸。</li>
 * </ul>
 */
@Slf4j
@Aspect
@Component
@Order(2)
@RequiredArgsConstructor
public class OpLogAspect {

    private static final int DETAIL_MAX = 200;

    private final OperationLogService operationLogService;

    /** 模块中文名映射：URI 第二段 -> 中文 */
    private static final Map<String, String> MODULE_MAP = new HashMap<>();
    static {
        MODULE_MAP.put("device", "设备");
        MODULE_MAP.put("scene", "场景");
        MODULE_MAP.put("room", "房间");
        MODULE_MAP.put("address", "地址");
        MODULE_MAP.put("cart", "购物车");
        MODULE_MAP.put("order", "订单");
        MODULE_MAP.put("user", "用户");
        MODULE_MAP.put("product", "商品");
        MODULE_MAP.put("goods", "商品");
        MODULE_MAP.put("banner", "轮播图");
        MODULE_MAP.put("oplog", "操作日志");
    }

    @Pointcut("within(@org.springframework.web.bind.annotation.RestController *)")
    public void controllerPointcut() {
    }

    @Around("controllerPointcut()")
    public Object around(ProceedingJoinPoint pjp) throws Throwable {
        HttpServletRequest request = currentRequest();
        String method = request != null ? request.getMethod() : "";
        String uri = request != null ? request.getRequestURI() : "";

        // 只记录写操作
        boolean write = "POST".equalsIgnoreCase(method)
                || "PUT".equalsIgnoreCase(method)
                || "DELETE".equalsIgnoreCase(method);

        Object result;
        try {
            result = pjp.proceed();
        } finally {
            if (write && request != null) {
                try {
                    recordLog(request, method, uri);
                } catch (Exception e) {
                    log.warn("[操作日志] 落库失败（已忽略）：{}", e.getMessage());
                }
            }
        }
        return result;
    }

    private void recordLog(HttpServletRequest request, String method, String uri) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            userId = 0L;
        }

        String[] parts = uri.split("/");
        String seg = parts.length >= 3 ? parts[2] : "";
        String module = MODULE_MAP.getOrDefault(seg, seg.isEmpty() ? "未知" : seg);

        String action = resolveAction(uri, method, module);

        String detail = buildDetail(request, method, uri);

        OperationLog item = new OperationLog();
        item.setUserId(userId);
        item.setModule(module);
        item.setAction(action);
        item.setDetail(detail);
        operationLogService.record(item);

        log.info("[操作日志] 用户#{} {} · {} {}", userId, module, action, detail);
    }

    private String resolveAction(String uri, String method, String module) {
        if (uri.contains("/control")) {
            return "控制设备";
        }
        if (uri.contains("/run")) {
            return "执行场景";
        }
        if (uri.contains("/toggle")) {
            return "切换场景状态";
        }
        if (uri.contains("/water")) {
            return "水泵浇水";
        }
        if (uri.contains("/refresh")) {
            return "刷新环境";
        }
        if ("POST".equalsIgnoreCase(method)) {
            return "新增" + module;
        }
        if ("PUT".equalsIgnoreCase(method)) {
            return "修改" + module;
        }
        if ("DELETE".equalsIgnoreCase(method)) {
            return "删除" + module;
        }
        return method;
    }

    private String buildDetail(HttpServletRequest request, String method, String uri) {
        String body = readCachedBody(request);
        if (body == null || body.isBlank()) {
            String query = request.getQueryString();
            body = query != null ? ("?" + query) : "";
        }
        body = maskSensitive(body);
        if (body.length() > DETAIL_MAX) {
            body = body.substring(0, DETAIL_MAX) + "…";
        }
        return method + " " + uri + " " + body;
    }

    private String readCachedBody(HttpServletRequest request) {
        try {
            ContentCachingRequestWrapper wrapper =
                    WebUtils.getNativeRequest(request, ContentCachingRequestWrapper.class);
            if (wrapper != null) {
                byte[] buf = wrapper.getContentAsByteArray();
                if (buf != null && buf.length > 0) {
                    return new String(buf, StandardCharsets.UTF_8);
                }
            }
        } catch (Exception ignored) {
            // 读不到就用空串，不阻塞主流程
        }
        return "";
    }

    /** 把 password / token / pwd 等敏感字段值脱敏 */
    private String maskSensitive(String text) {
        if (text == null || text.isBlank()) {
            return text;
        }
        return text.replaceAll("\"(password|pwd|token|passwd)\"\\s*:\\s*\"[^\"]*\"",
                "\"$1\":\"***\"");
    }

    private HttpServletRequest currentRequest() {
        try {
            var attrs = org.springframework.web.context.request.RequestContextHolder
                    .getRequestAttributes();
            if (attrs instanceof org.springframework.web.context.request.ServletRequestAttributes) {
                return ((org.springframework.web.context.request.ServletRequestAttributes) attrs)
                        .getRequest();
            }
        } catch (Exception ignored) {
            // 非 Web 上下文（理论上不会进切面）返回 null
        }
        return null;
    }
}
