package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.entity.Goods;
import com.smarthome.entity.GoodsCategory;
import com.smarthome.service.GoodsService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 商品模块（浏览公开，不需要登录）。白名单已在 WebConfig 放行 /api/goods/**。
 */
@RestController
@RequestMapping("/api/goods")
@RequiredArgsConstructor
public class GoodsController {

    private final GoodsService goodsService;

    @GetMapping("/categories")
    public Result<List<GoodsCategory>> categories() {
        return Result.ok(goodsService.categories());
    }

    @GetMapping("/banners")
    public Result<List<String>> banners() {
        return Result.ok(goodsService.banners());
    }

    @GetMapping("/list")
    public Result<List<Goods>> list(@RequestParam(required = false) Long categoryId,
                                    @RequestParam(required = false) String keyword) {
        return Result.ok(goodsService.list(categoryId, keyword));
    }

    @GetMapping("/{id}")
    public Result<Goods> detail(@PathVariable Long id) {
        return Result.ok(goodsService.detail(id));
    }
}
