package com.smarthome.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 加入购物车的入参（POST /api/cart）。
 */
@Data
public class CartAddDTO {

    @NotNull(message = "商品不能为空")
    private Long goodsId;

    @NotNull(message = "数量不能为空")
    @Min(value = 1, message = "数量至少 1 件")
    @Max(value = 99, message = "单次最多 99 件")
    private Integer quantity;
}
