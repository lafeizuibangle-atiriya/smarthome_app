package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.entity.Banner;
import com.smarthome.service.BannerService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** 轮播图（公开数据，拦截器已放行 /api/banner/**） */
@RestController
@RequestMapping("/api/banner")
@RequiredArgsConstructor
public class BannerController {

    private final BannerService bannerService;

    /** position: home=主页 / product=产品页 / shop=商城；不传返回全部 */
    @GetMapping("/list")
    public Result<List<Banner>> list(@RequestParam(required = false) String position) {
        return Result.ok(bannerService.listByPosition(position));
    }
}
