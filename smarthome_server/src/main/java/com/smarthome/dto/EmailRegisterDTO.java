package com.smarthome.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 邮箱注册入参（POST /api/user/register/email）。
 *
 * <p>流程：用户填邮箱 → 点「获取验证码」→ 收到 6 位验证码（60 秒有效，存 Redis）
 * → 填密码 + 验证码提交注册。
 *
 * <p>【username 复用邮箱】邮箱注册的用户 username 直接存邮箱地址，
 * 这样普通登录接口（username + password）不用改就能登录。
 */
@Data
public class EmailRegisterDTO {

    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    private String email;

    /** 6 位数字验证码 */
    @NotBlank(message = "验证码不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "验证码应为 6 位数字")
    private String code;

    /** 手机号（2026-09-29 新增，必填，唯一） */
    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 32, message = "密码长度 6~32 位")
    private String password;

    /** 昵称可空，为空时后端用邮箱前缀兜底 */
    @Size(max = 20, message = "昵称最长 20 个字符")
    private String nickname;
}
