package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

/**
 * 收货地址入参（新增/修改共用）。修改时带 id。
 */
@Data
public class AddressDTO {

    private Long id;

    @NotBlank(message = "收货人不能为空")
    private String receiver;

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "所在地区不能为空")
    private String region;   // 省市区，如 "广东省 深圳市 南山区"

    @NotBlank(message = "详细地址不能为空")
    private String detail;   // 详细地址

    private Integer isDefault; // 1 默认 / 0 非默认
}
