package com.smarthome.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 修改个人资料入参（PUT /api/user/profile）。
 */
@Data
public class ProfileDTO {

    @Size(max = 20, message = "昵称最长 20 个字符")
    private String nickname;

    @Size(max = 255, message = "头像地址过长")
    private String avatar;
}
