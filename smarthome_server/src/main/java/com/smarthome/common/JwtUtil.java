package com.smarthome.common;

import cn.hutool.jwt.JWT;
import lombok.extern.slf4j.Slf4j;

import java.util.Date;

/**
 * 【阶段① · A 负责】JWT 工具（手册 2.4 节）—— 全组登录鉴权的基础。
 *
 * <p>两个静态方法：
 * <ul>
 *   <li>{@code createToken(Long userId)}：登录成功后签发 token，payload 里只放 userId；</li>
 *   <li>{@code verifyToken(String token)}：校验签名 + 有效期，通过返回 userId，否则返回 null。</li>
 * </ul>
 *
 * <p>⚠ 两个真实踩过的坑（总方案踩坑 10）——写错的表现是"登录返回 200 和 token，
 * 但之后所有接口 401，控制台一行报错都没有"：
 * <ol>
 *   <li>不要用 {@code jwt.verify()} —— 它只验签名、**不验有效期**，过期 token 也能通过！
 *       必须用 {@code jwt.validate(0)}（签名 + 有效期一起验）。</li>
 *   <li>{@code getPayload("userId")} 取出来的是 Number 子类，直接强转 Integer 会抛
 *       ClassCastException。要先判 {@code instanceof Number} 再 {@code longValue()}。</li>
 * </ol>
 *
 * <p>⚠ 兜底的 catch 不要静默 return null —— 至少打一行 WARN，
 * 否则会把代码 bug 一起吞掉，变成"功能静默失效"（总方案踩坑 10 的通用教训）。
 *
 * <p>自测 4 种 token：正常（返回 userId）/ 篡改（null）/ 过期（null）/ 空串乱串（null）。
 */
@Slf4j
public class JwtUtil {

    /** 签名密钥。真实项目要放配置中心，课程 Demo 直接写常量。 */
    private static final String SECRET = "smarthome-secret-2024";

    /** 有效期 7 天（毫秒）。注意末尾的 L：不加的话前面的乘法按 int 算，虽不溢出但不规范。 */
    private static final long EXPIRE = 7 * 24 * 3600 * 1000L;

    private JwtUtil() {
        // 工具类，禁止实例化
    }

    /** 生成 token，payload 里放 userId */
    public static String createToken(Long userId) {
        return JWT.create()
                .setPayload("userId", userId)
                .setExpiresAt(new Date(System.currentTimeMillis() + EXPIRE))
                .setKey(SECRET.getBytes())
                .sign();
    }

    /**
     * 校验并取出 userId；无效或过期返回 null。
     *
     * <p>注意：① 用 validate(0) 而不是 verify()；② payload 里的数字先转 Number 再 longValue()。
     */
    public static Long verifyToken(String token) {
        if (token == null || token.isEmpty()) {
            return null;            // 空 token 是常态（未登录访问白名单外的接口），不算异常，不记日志
        }
        try {
            JWT jwt = JWT.of(token).setKey(SECRET.getBytes());
            // validate(0)：签名与有效期一起校验；返回 false 即"签名不对或已过期"
            if (!jwt.validate(0)) {
                return null;
            }
            Object raw = jwt.getPayload("userId");
            if (raw == null) {
                return null;
            }
            // 坑 2：Hutool 解出来的是 NumberWithFormat（Number 子类），不是 Integer
            if (raw instanceof Number) {
                return ((Number) raw).longValue();
            }
            return Long.valueOf(raw.toString());
        } catch (Exception e) {
            // 不能静默吞掉：正常情况是"token 格式乱"（用户乱串），
            // 但也有可能是我们自己的 bug，留一行日志才能分辨（总方案踩坑 10）
            log.warn("[鉴权] token 解析失败：{}", e.getMessage());
            return null;
        }
    }
}
