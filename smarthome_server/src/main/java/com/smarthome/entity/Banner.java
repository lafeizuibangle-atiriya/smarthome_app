package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 轮播图表 banner（position 区分 home 主页 / product 产品页 / shop 商城）。
 */
@Data
@TableName("banner")
public class Banner {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String title;
    private String imageUrl;   // 后端静态资源路径
    private String linkUrl;
    private String position;   // home / product / shop
    private Integer sort;
    private Integer enabled;   // 1 启用 / 0 停用
}
