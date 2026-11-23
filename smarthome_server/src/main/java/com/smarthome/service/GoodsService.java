package com.smarthome.service;

import com.smarthome.entity.Goods;
import com.smarthome.entity.GoodsCategory;

import java.util.List;

/** 商城商品模块（接口文档七，浏览公开）。 */
public interface GoodsService {
    /** 金刚区分类（带 id，前端点击分类可按 categoryId 筛选） */
    List<GoodsCategory> categories();
    /** Banner：Demo 取销量前 3 的商品封面（图片名数组） */
    List<String> banners();
    /** 仅上架商品；categoryId 为空或 0 表示全部 */
    List<Goods> list(Long categoryId, String keyword);
    Goods detail(Long id);
}
