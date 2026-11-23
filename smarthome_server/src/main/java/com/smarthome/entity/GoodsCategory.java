package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 商品分类表 goods_category（商城金刚区）。
 */
@Data
@TableName("goods_category")
public class GoodsCategory {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private Integer sort;
}
