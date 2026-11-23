package com.smarthome.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.smarthome.entity.Product;
import org.apache.ibatis.annotations.Mapper;

/**
 * Product 数据层：单表 CRUD 全部继承 BaseMapper，一行 SQL 不用写。
 * 【三层红线】Mapper 只写 SQL，不做业务判断；业务规则在 Service（总方案 3.1）。
 */
@Mapper
public interface ProductMapper extends BaseMapper<Product> {
}
