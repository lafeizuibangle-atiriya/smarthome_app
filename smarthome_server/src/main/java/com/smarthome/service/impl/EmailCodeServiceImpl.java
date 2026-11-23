package com.smarthome.service.impl;

import com.smarthome.common.BizException;
import com.smarthome.service.EmailCodeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;

/**
 * 邮箱验证码服务实现：Redis 存验证码（60 秒 TTL）+ QQ SMTP 发信。
 *
 * <p>【为什么用 Redis】验证码天然是「短生命周期、高频读写」的数据，
 * 用 Redis 的 EXPIRE 一行搞定 60 秒过期，不用自己起定时器清理；
 * 多实例部署时验证码也是全局共享的（内存 Map 只能单机用）。
 *
 * <p>【防刷两条】：
 * <ul>
 *   <li>key 还存在 = 上一个验证码仍有效 → 拒绝重发（60 秒冷却）</li>
 *   <li>校验通过立刻删 key → 一个验证码只能注册一次</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EmailCodeServiceImpl implements EmailCodeService {

    /** Redis key 前缀：email:code:xxx@qq.com */
    private static final String KEY_PREFIX = "email:code:";

    /** 验证码有效期（秒）—— 需求明确 60 秒 */
    private static final Duration TTL = Duration.ofSeconds(60);

    private static final String EMAIL_REGEX =
            "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";

    private final StringRedisTemplate redisTemplate;
    private final JavaMailSender mailSender;

    /** 发件人 = application.yml 的 spring.mail.username（QQ 邮箱要求 from 必须是认证过的账号） */
    @Value("${spring.mail.username}")
    private String from;

    @Override
    public void send(String email) {
        // 1. 后端再校验一次邮箱格式（前端拦了也要防绕过）
        if (email == null || !email.matches(EMAIL_REGEX)) {
            throw new BizException("邮箱格式不正确");
        }

        // 2. 60 秒冷却：上一个码还没过期就不允许重发
        String key = KEY_PREFIX + email;
        if (Boolean.TRUE.equals(redisTemplate.hasKey(key))) {
            throw new BizException("验证码已发送，60 秒内请勿重复获取");
        }

        // 3. 生成 6 位数字验证码（SecureRandom 防被猜）
        String code = String.format("%06d", new SecureRandom().nextInt(1_000_000));

        // 4. 存 Redis，60 秒自动过期（不需要任何定时清理任务）
        redisTemplate.opsForValue().set(key, code, TTL);

        // 5. 发邮件（SimpleMailMessage 足够；HTML 邮件用 MimeMessageHelper）
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            msg.setFrom(from);
            msg.setTo(email);
            msg.setSubject("智慧家居 App 注册验证码");
            msg.setText("您的注册验证码是：" + code
                    + "\n有效期 60 秒，请尽快填写。如非本人操作请忽略本邮件。");
            mailSender.send(msg);
        } catch (Exception e) {
            // 发送失败必须把已存的验证码删掉，否则 60 秒内用户收不到信又不能重发
            redisTemplate.delete(key);
            log.error("[邮箱验证码] 发送失败：email={} 原因={}", email, e.getMessage());
            throw new BizException("验证码邮件发送失败，请稍后重试");
        }

        // 控制台打印（不打印验证码本身，只打结论；真实验证码只在邮件里）
        log.info("[邮箱验证码] 已发送：email={} 有效期 60 秒", email);
    }

    @Override
    public void verify(String email, String code) {
        if (email == null || code == null || code.isEmpty()) {
            throw new BizException("请填写验证码");
        }
        String key = KEY_PREFIX + email;
        String saved = redisTemplate.opsForValue().get(key);

        // 查不到 = 过期（60 秒）或根本没发过
        if (saved == null) {
            throw new BizException("验证码已过期，请重新获取");
        }
        if (!saved.equals(code.trim())) {
            throw new BizException("验证码错误");
        }

        // 一次性使用：校验通过立刻删，防止拿同一个码注册两次
        redisTemplate.delete(key);
        log.info("[邮箱验证码] 校验通过：email={}", email);
    }
}
