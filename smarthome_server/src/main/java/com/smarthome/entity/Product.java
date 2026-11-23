package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 产品库 product（只展示不卖，与 goods 通过 related_goods_id 关联实现"去商城看看"）。
 */
@Data
@TableName("product")
public class Product {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private String category;
    private String cover;
    private String slogan;       // 一句话卖点
    private String description;
    private String specs;        // JSON 规格参数数组
    private String tags;         // "WiFi,联动"
    private Long relatedGoodsId;
}
