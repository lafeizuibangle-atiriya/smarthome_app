package com.smarthome.service;

import com.smarthome.entity.Banner;

import java.util.List;

/** 轮播图业务接口 */
public interface BannerService {

    /** 按位置取启用中的轮播图，按 sort 升序 */
    List<Banner> listByPosition(String position);
}
