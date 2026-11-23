package com.smarthome.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.util.ContentCachingRequestWrapper;

import java.io.IOException;

/**
 * 请求体缓存过滤器：把 HttpServletRequest 包成 ContentCachingRequestWrapper，
 * 让 OpLogAspect 在 Controller 执行完后仍能读取到 JSON 请求体（用于操作日志脱敏落库）。
 *
 * <p>不加它，请求体输入流只能被 Spring 的 @RequestBody 解析器读一次，
 * 切面想再读就读不到了。过滤器在所有拦截器 / 控制器之前执行，
 * 必须把包装后的 request 一路往后传（chain.doFilter(wrapper, ...)）。
 */
@Component
@Order(1)
public class RequestCachingFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        if (request instanceof HttpServletRequest) {
            chain.doFilter(new ContentCachingRequestWrapper((HttpServletRequest) request), response);
        } else {
            chain.doFilter(request, response);
        }
    }
}
