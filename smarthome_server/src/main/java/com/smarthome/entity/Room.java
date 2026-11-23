package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 房间实体（对应表 room）。归属用户，数据隔离靠 userId。
 * 房间名里含"厨房/厨/燃气/灶"时会被判定为需要燃气检测（见 DeviceServiceImpl 4.6 节）。
 */
@Data
@TableName("room")
public class Room {
    @TableId(type = IdType.AUTO)
    private Long id;

    /** 归属用户：数据隔离的根 —— 凡是查房间都必须带上这个条件 */
    private Long userId;

    /** 房间名。名字里含"厨房/厨/燃气/灶"时会被判定为需要燃气检测 */
    private String name;

    /** 首页房间切换的显示顺序，越小越靠前（overview 里按它排序） */
    private Integer sort;
}
