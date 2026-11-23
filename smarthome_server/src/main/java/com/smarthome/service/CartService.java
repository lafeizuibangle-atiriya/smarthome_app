package com.smarthome.service;

import com.smarthome.vo.CartItemVO;

import java.util.List;

/** 购物车模块（手册 7.1）。 */
public interface CartService {
    void add(Long userId, Long goodsId, Integer quantity);
    List<CartItemVO> list(Long userId);
    void updateQuantity(Long userId, Long cartItemId, Integer quantity);
    void remove(Long userId, Long cartItemId);
    void clear(Long userId);
}
