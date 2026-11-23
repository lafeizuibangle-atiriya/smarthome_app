package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 添加设备的入参（POST /api/device 的请求体）。
 * 对应前端：AddDevicePage → DeviceApi.addDevice(roomId, name, type)
 */
@Data
public class DeviceAddDTO {

    @NotNull(message = "房间不能为空")
    private Long roomId;    // 设备加到哪个房间（后端会校验这个房间是不是你的）

    @NotBlank(message = "设备名不能为空")
    @Size(max = 20, message = "设备名最长 20 个字符")
    private String name;    // 设备名，如"客厅主灯"

    /** 设备类型：light 灯 / ac 空调 / socket 插座 / curtain 窗帘 / pump 水泵 / lock 门禁 */
    @NotBlank(message = "设备类型不能为空")
    @Pattern(regexp = "^[a-z_]{2,20}$", message = "设备类型格式不合法")
    private String type;
}
