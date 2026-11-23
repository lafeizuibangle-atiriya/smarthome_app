package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 房间入参（新增/重命名共用）。新增只用 name；重命名带 id + name。
 */
@Data
public class RoomDTO {

    private Long id;

    @NotBlank(message = "房间名不能为空")
    @Size(max = 10, message = "房间名最长 10 个字符")
    private String name;
}
