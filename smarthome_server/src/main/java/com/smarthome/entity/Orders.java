package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单主表 orders（类名用 Orders 避开 SQL 关键字 order）。
 * status: 0 待付款 / 1 已付款 / 2 已完成 / 3 已取消。
 * receiver* 三字段是下单时从地址复制的快照，之后改地址不影响历史订单。
 */
@Data
@TableName("orders")
public class Orders {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String orderNo;       // 唯一订单号
    private Long userId;
    private Long addressId;
    private BigDecimal totalAmount;
    private Integer status;
    private LocalDateTime payTime;
    private LocalDateTime createTime;
    private String receiverName;
    private String receiverPhone;
    private String receiverAddress;
}
