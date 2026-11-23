package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.entity.Product;
import com.smarthome.mapper.ProductMapper;
import com.smarthome.service.ProductService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ProductServiceImpl implements ProductService {

    private final ProductMapper productMapper;

    /** 分类列表：直接从已有数据里去重取出，不用单独建分类表 */
    @Override
    public List<String> categories() {
        return productMapper.selectList(null).stream()
                .map(Product::getCategory)
                .distinct()
                .collect(Collectors.toList());
    }

    @Override
    public List<Product> list(String category, String keyword) {
        LambdaQueryWrapper<Product> wrapper = new LambdaQueryWrapper<>();
        if (category != null && !category.isEmpty()) {
            wrapper.eq(Product::getCategory, category);
        }
        if (keyword != null && !keyword.isEmpty()) {
            wrapper.like(Product::getName, keyword);     // 模糊搜索
        }
        return productMapper.selectList(wrapper.orderByAsc(Product::getId));
    }

    @Override
    public Product detail(Long id) {
        Product product = productMapper.selectById(id);
        if (product == null) throw new BizException("产品不存在");
        return product;
    }
}
