package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 商品表 goods（可购买；product 只做介绍）。
 * 【红线】金额一律 BigDecimal（数据库 DECIMAL(10,2)），绝不用 float/double。
 */
@Data
@TableName("goods")
public class Goods {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long categoryId;
    private String name;
    private String cover;
    private String images;       // JSON 数组轮播图
    private BigDecimal price;    // 现价
    private BigDecimal originPrice; // 划线原价
    private Integer stock;
    private Integer sales;
    private String detail;
    private String tags;         // 搜索标签（逗号分隔），配合 list 三字段搜索
    private Integer status;      // 1 上架 / 0 下架
}
