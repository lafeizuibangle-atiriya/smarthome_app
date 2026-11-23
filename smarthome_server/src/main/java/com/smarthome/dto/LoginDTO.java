package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 【阶段① · B 负责】登录入参（POST /api/user/login）。
 *
 * <p>字段与《03_接口文档.md》二严格对齐。前端对应 {@code api/UserApi.ets} 的
 * {@code LoginParam} interface —— 两边字段名必须一模一样，写错了后端收到的就是 null。
 *
 * <p>【为什么不直接用 entity.User 接参】Entity 里有 password 密文、createTime 等
 * 前端不该传也不该看的字段。用 DTO 只暴露需要的字段，是三层架构的硬要求。
 *
 * <p>【参数校验】2026-11-23 加 @NotBlank，Controller 用 @Valid 触发；
 * 校验失败由 GlobalExceptionHandler 统一转 400。
 */
@Data
public class LoginDTO {

    @NotBlank(message = "用户名不能为空")
    private String username;

    @NotBlank(message = "密码不能为空")
    private String password;
}
