package com.smarthome.vo;

import lombok.Data;
import java.math.BigDecimal;

/** 购物车项出参（联表 goods 的最新信息）。 */
@Data
public class CartItemVO {
    private Long id;
    private Long goodsId;
    private String goodsName;
    private String goodsCover;
    private BigDecimal price;    // 商品最新单价
    private Integer quantity;
}
