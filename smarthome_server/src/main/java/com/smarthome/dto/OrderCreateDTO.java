package com.smarthome.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;
import java.util.List;
import java.util.Map;

/**
 * 提交订单入参（POST /api/order/create）。
 * items 格式：[{ "goodsId": 1, "quantity": 2 }]
 *
 * <p>【接口幂等】2026-11-23 新增 {@code requestId}：客户端每次提交订单生成一个
 * 随机串（UUID）并在重试时复用同一个值。后端用它做幂等键——同一 requestId 的
 * 重复提交只会真正下单一次，重试时返回第一次的订单结果。
 * 不传 requestId 则按旧行为直接下单（兼容旧客户端）。
 */
@Data
public class OrderCreateDTO {

    @jakarta.validation.constraints.NotNull(message = "收货地址不能为空")
    private Long addressId;

    @jakarta.validation.constraints.NotEmpty(message = "请选择要购买的商品")
    /** 格式：[{ "goodsId": 1, "quantity": 2 }] */
    private List<Map<String, Object>> items;

    /** 幂等键：客户端生成的唯一串，同一单的多次提交必须复用同一个值（可空，为空不做幂等） */
    @Pattern(regexp = "^$|^[\\w\\-]{8,64}$", message = "requestId 格式不合法")
    private String requestId;
}
