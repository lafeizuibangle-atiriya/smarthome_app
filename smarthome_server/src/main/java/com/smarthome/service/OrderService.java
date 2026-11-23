package com.smarthome.service;

import com.smarthome.common.PageVO;
import com.smarthome.dto.OrderCreateDTO;
import com.smarthome.vo.OrderVO;

import java.util.List;

/** 订单模块——本项目最核心的业务（手册 7.2）。 */
public interface OrderService {
    OrderVO create(Long userId, OrderCreateDTO dto);
    void pay(Long orderId, Long userId);
    void cancel(Long orderId, Long userId);
    List<OrderVO> list(Long userId, Integer status);

    /** 订单列表分页版（2026-11-23 后端增强） */
    PageVO<OrderVO> page(Long userId, Integer status, int pageNum, int pageSize);

    OrderVO detail(Long orderId, Long userId);
}
