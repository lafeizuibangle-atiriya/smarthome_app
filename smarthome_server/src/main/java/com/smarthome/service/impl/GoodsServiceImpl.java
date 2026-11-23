package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.entity.Goods;
import com.smarthome.entity.GoodsCategory;
import com.smarthome.mapper.GoodsCategoryMapper;
import com.smarthome.mapper.GoodsMapper;
import com.smarthome.service.GoodsService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GoodsServiceImpl implements GoodsService {

    private final GoodsMapper goodsMapper;
    private final GoodsCategoryMapper goodsCategoryMapper;

    /** 金刚区分类（带 id + name，前端点击分类按 categoryId 筛选；2026-09-29 从纯名字数组升级） */
    @Override
    public List<GoodsCategory> categories() {
        return goodsCategoryMapper.selectList(
                new LambdaQueryWrapper<GoodsCategory>().orderByAsc(GoodsCategory::getSort));
    }

    /** Banner：Demo 取销量前 3 的商品封面（图片名数组） */
    @Override
    public List<String> banners() {
        return goodsMapper.selectList(new LambdaQueryWrapper<Goods>()
                        .eq(Goods::getStatus, 1)
                        .orderByDesc(Goods::getSales)
                        .last("LIMIT 3"))
                .stream().map(Goods::getCover).collect(Collectors.toList());
    }

    /**
     * 仅上架商品；categoryId 为空或 0 表示全部。
     * 【2026-09-29 搜索增强】关键字前后去空格，并且同时匹配
     * 商品名 / 详情 / 标签三个字段（like 任意一个命中即返回）——
     * 以前只 like name，搜"护眼""静音"这类写在详情里的词全都搜不到。
     */
    @Override
    public List<Goods> list(Long categoryId, String keyword) {
        LambdaQueryWrapper<Goods> wrapper = new LambdaQueryWrapper<Goods>()
                .eq(Goods::getStatus, 1);            // 只查上架商品
        if (categoryId != null && categoryId > 0) {
            wrapper.eq(Goods::getCategoryId, categoryId);
        }
        if (keyword != null && !keyword.trim().isEmpty()) {
            String kw = keyword.trim();
            wrapper.and(w -> w.like(Goods::getName, kw)
                    .or().like(Goods::getDetail, kw)
                    .or().like(Goods::getTags, kw));
        }
        return goodsMapper.selectList(wrapper.orderByDesc(Goods::getSales));
    }

    @Override
    public Goods detail(Long id) {
        Goods goods = goodsMapper.selectById(id);
        if (goods == null) throw new BizException("商品不存在");
        return goods;
    }
}
