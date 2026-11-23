package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.entity.Product;
import com.smarthome.service.ProductService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 产品库接口（只展示、不售卖）。公开接口，不需要登录。
 */
@RestController
@RequestMapping("/api/product")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    @GetMapping("/categories")
    public Result<List<String>> categories() {
        return Result.ok(productService.categories());
    }

    @GetMapping("/list")
    public Result<List<Product>> list(@RequestParam(required = false) String category,
                                      @RequestParam(required = false) String keyword) {
        return Result.ok(productService.list(category, keyword));
    }

    @GetMapping("/{id}")
    public Result<Product> detail(@PathVariable Long id) {
        return Result.ok(productService.detail(id));
    }
}
