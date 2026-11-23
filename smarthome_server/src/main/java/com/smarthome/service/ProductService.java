package com.smarthome.service;

import com.smarthome.entity.Product;

import java.util.List;

/** 产品库模块（手册第六章，公开接口不用登录）。 */
public interface ProductService {
    List<String> categories();
    List<Product> list(String category, String keyword);
    Product detail(Long id);
}
