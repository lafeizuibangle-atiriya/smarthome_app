package com.smarthome.vo;

import com.smarthome.entity.OrderItem;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/** 订单出参。items 是订单明细快照列表。 */
@Data
public class OrderVO {
    private Long id;
    private String orderNo;
    private BigDecimal totalAmount;
    private Integer status;       // 0 待付款 / 1 已付款 / 2 已完成 / 3 已取消
    private LocalDateTime createTime;
    private String receiverName;
    private String receiverPhone;
    private String receiverAddress;
    private List<OrderItem> items;
}
