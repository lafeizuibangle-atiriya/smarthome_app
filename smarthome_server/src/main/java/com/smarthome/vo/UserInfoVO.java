package com.smarthome.vo;

import lombok.Data;

/**
 * "我的"页用户信息（GET /api/user/info 的 data）。
 * 字段：id / username / nickname / avatar / deviceCount / orderCount
 *       / orderPending(待付款数) / orderPaid(已付款数)。
 */
@Data
public class UserInfoVO {
    private Long id;
    private String username;
    private String nickname;
    private String avatar;

    /** 设备数（"我的"页展示） */
    private Integer deviceCount;

    /** 订单数（"我的"页展示） */
    private Integer orderCount;

    /** 待付款订单数（"我的"页订单快捷入口角标） */
    private Integer orderPending;

    /** 已付款订单数（"我的"页订单快捷入口角标） */
    private Integer orderPaid;
}
