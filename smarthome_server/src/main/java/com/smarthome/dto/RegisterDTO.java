package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 【阶段① · B 负责】注册入参（POST /api/user/register）。
 *
 * <p>比登录多一个 {@code nickname}。前端对应 {@code api/UserApi.ets} 的 {@code RegisterParam}。
 *
 * <p>【nickname 可以为空】Service 里做了兜底：为空时用 username 代替
 * （见 {@code UserServiceImpl.register}），所以前端不必强制填。
 */
@Data
public class RegisterDTO {

    @NotBlank(message = "用户名不能为空")
    @Size(max = 20, message = "用户名最长 20 个字符")
    private String username;

    @Size(max = 20, message = "昵称最长 20 个字符")
    private String nickname;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 32, message = "密码长度 6~32 位")
    private String password;
}
