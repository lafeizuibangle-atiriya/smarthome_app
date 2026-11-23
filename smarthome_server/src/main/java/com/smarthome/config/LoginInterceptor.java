package com.smarthome.config;

import com.smarthome.common.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 【阶段① · A 负责】登录拦截器（手册 2.5 节）：进 Controller 之前统一鉴权。
 *
 * <p>preHandle 逻辑：
 * <ol>
 *   <li>{@code Long userId = JwtUtil.verifyToken(request.getHeader("token"));}
 *       —— 请求头名字就叫 <b>token</b>，不是 Authorization！</li>
 *   <li>userId == null 时：写回 {"code":401,"msg":"请先登录"}（contentType=application/json;charset=utf-8）
 *       并 return false 拦截；</li>
 *   <li>通过则 {@code request.setAttribute("userId", userId)} 后放行 ——
 *       Controller 统一用 {@code (Long) request.getAttribute("userId")} 取当前登录人。</li>
 * </ol>
 *
 * <p>【为什么用 Response 直接写 JSON、不走 Result】拦截器在 Controller 之前执行，
 * 抛出的异常不会经过 {@code @RestControllerAdvice}，所以只能自己写响应体。
 * 字段名要和 {@link com.smarthome.common.Result} 保持一致（code / msg），
 * 否则前端的 401 判定会失效。
 *
 * <p>【和 WebConfig 的分工】这里只管"拦"，哪些路径放行由 {@link WebConfig} 的白名单决定。
 */
@Slf4j
public class LoginInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                             Object handler) throws Exception {
        Long userId = JwtUtil.verifyToken(request.getHeader("token"));
        if (userId == null) {
            // 注意 contentType 要带 charset，否则响应体里的中文会乱码
            response.setContentType("application/json;charset=utf-8");
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED); // 401，方便前端/测试按 HTTP 状态判断
            response.getWriter().write("{\"code\":401,\"msg\":\"请先登录\"}");
            log.info("[鉴权] 拦截未登录请求：{} {}", request.getMethod(), request.getRequestURI());
            return false;           // false = 到此为止，不再进 Controller
        }
        // 把登录人放进 request 作用域，Controller 里可直接取
        request.setAttribute("userId", userId);
        return true;                // true = 放行
    }
}
