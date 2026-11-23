package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 【阶段① · A 负责】收货地址表 address。
 *
 * <p>7 个字段：id / userId / receiver / phone / region(省市区) / detail(详细地址) / isDefault(1 默认)。
 *
 * <p>【一张表存"省市区 + 详细地址"两段】是为了少建一张行政区划表 ——
 * region 存 "广东省 深圳市 南山区" 这种空格分隔的字符串，
 * detail 存门牌号。演示够用，真实项目一般会拆成省/市/区三个字段或直接存经纬度。
 *
 * <p>【驼峰映射】数据库下划线 is_default ↔ Java isDefault，mybatis-plus 已全局配置。
 *
 * <p>⚠ 注意：这里<b>没有</b> user_id 上的外键约束（本项目全程不建外键），
 * 所以"地址只能属于自己"这条规则必须由 Service 层自己校验，不能指望数据库。
 */
@Data
@TableName("address")
public class Address {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 归属用户，对应 user.id。查询/删除时必须带上它，否则会越权操作别人的地址 */
    private Long userId;

    private String receiver;

    private String phone;

    /** 省市区，如 "广东省 深圳市 南山区" */
    private String region;

    /** 详细地址，如 "科技园路 1 号 101 室" */
    private String detail;

    /** 1 = 默认地址，0 = 非默认 */
    private Integer isDefault;
}
