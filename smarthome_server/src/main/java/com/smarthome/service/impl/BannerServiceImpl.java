package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.entity.Banner;
import com.smarthome.mapper.BannerMapper;
import com.smarthome.service.BannerService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/** 轮播图业务实现：查询逻辑很薄，但保持三层结构统一 */
@Service
@RequiredArgsConstructor
public class BannerServiceImpl implements BannerService {

    private final BannerMapper bannerMapper;

    @Override
    public List<Banner> listByPosition(String position) {
        return bannerMapper.selectList(new LambdaQueryWrapper<Banner>()
                .eq(Banner::getEnabled, 1)
                .eq(position != null && !position.isEmpty(), Banner::getPosition, position)
                .orderByAsc(Banner::getSort)
                .orderByAsc(Banner::getId));
    }
}
