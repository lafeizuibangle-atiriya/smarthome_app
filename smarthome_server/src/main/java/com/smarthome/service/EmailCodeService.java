package com.smarthome.service;

/**
 * 邮箱验证码服务（邮箱注册功能）。
 *
 * <p>验证码生命周期：
 * <ol>
 *   <li>{@code send}：生成 6 位数字验证码 → 存 Redis（key = email:code:{邮箱}，TTL 60 秒）→ QQ SMTP 发邮件；
 *       60 秒内重复请求会直接拒绝（key 还在 = 上一个码仍有效，天然就是重发冷却）</li>
 *   <li>{@code verify}：校验通过后立即删除 key（一个验证码只能用一次）</li>
 * </ol>
 */
public interface EmailCodeService {

    /**
     * 给指定邮箱发送 6 位注册验证码（60 秒有效）。
     *
     * @param email 已通过格式校验且未注册过的邮箱
     */
    void send(String email);

    /**
     * 校验验证码。
     *
     * @throws com.smarthome.common.BizException 验证码过期 / 错误
     */
    void verify(String email, String code);
}
