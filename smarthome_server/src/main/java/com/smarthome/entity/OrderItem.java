package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 订单明细表 order_item。
 * 冗余商品名与图片快照——商品下架/改价后历史订单显示仍正确。
 */
@Data
@TableName("order_item")
public class OrderItem {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long orderId;
    private Long goodsId;
    private String goodsName;
    private String goodsCover;
    private BigDecimal price;    // 下单时快照单价
    private Integer quantity;
}
