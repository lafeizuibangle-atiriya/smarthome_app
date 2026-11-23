package com.smarthome.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 【阶段① · A 负责】注册登录拦截器（手册 2.5 节）。
 *
 * <p>{@code addPathPatterns("/api/**")} 表示默认所有接口都要登录，
 * 再靠 {@code excludePathPatterns} 开白名单 —— <b>这种"默认关、显式开"的写法更安全</b>，
 * 以后新增接口忘了配也只会"要登录"，而不是"漏鉴权"。
 *
 * <p>白名单三类：
 * <ul>
 *   <li>登录/注册：用户还没 token，必须放行；</li>
 *   <li>产品库 / 商品 / 轮播图：纯浏览内容，不需要登录也能看（未登录也能逛商城）；</li>
 * </ul>
 * 其余（用户信息、地址、房间、设备、场景、购物车、订单、操作日志）一律要 token。
 *
 * <p>⚠ 用 {@code /**} 通配子路径：写 {@code "/api/product"} 只能匹配它本身，
 * 写 {@code "/api/product/**"} 才能匹配 {@code /api/product/categories}。
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new LoginInterceptor())
                .addPathPatterns("/api/**")
                .excludePathPatterns(
                        "/api/user/login",          // 登录
                        "/api/user/register",       // 注册（账号密码）
                        "/api/user/email/code",     // 发送邮箱验证码（邮箱注册）
                        "/api/user/register/email", // 邮箱注册
                        "/api/product/**",          // 产品库公开
                        "/api/goods/**",            // 商品浏览公开
                        "/api/banner/**"            // 轮播图公开
                );
    }
}
