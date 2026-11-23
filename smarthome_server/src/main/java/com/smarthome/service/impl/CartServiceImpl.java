package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.entity.CartItem;
import com.smarthome.entity.Goods;
import com.smarthome.mapper.CartItemMapper;
import com.smarthome.mapper.GoodsMapper;
import com.smarthome.service.CartService;
import com.smarthome.vo.CartItemVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CartServiceImpl implements CartService {

    private final CartItemMapper cartItemMapper;
    private final GoodsMapper goodsMapper;

    @Override
    public void add(Long userId, Long goodsId, Integer quantity) {
        Goods goods = goodsMapper.selectById(goodsId);
        if (goods == null) throw new BizException("商品不存在");
        if (goods.getStock() < quantity) throw new BizException("库存不足");

        // 已在购物车就累加数量，避免同商品出现多行
        CartItem exist = cartItemMapper.selectOne(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .eq(CartItem::getGoodsId, goodsId));
        if (exist != null) {
            exist.setQuantity(exist.getQuantity() + quantity);
            cartItemMapper.updateById(exist);
        } else {
            CartItem item = new CartItem();
            item.setUserId(userId);
            item.setGoodsId(goodsId);
            item.setQuantity(quantity);
            cartItemMapper.insert(item);
        }
    }

    @Override
    public List<CartItemVO> list(Long userId) {
        return cartItemMapper.selectCartWithGoods(userId);
    }

    @Override
    public void updateQuantity(Long userId, Long cartItemId, Integer quantity) {
        if (quantity <= 0) throw new BizException("数量必须大于 0");
        CartItem item = cartItemMapper.selectById(cartItemId);
        if (item == null || !item.getUserId().equals(userId)) throw new BizException("购物车项不存在");
        item.setQuantity(quantity);
        cartItemMapper.updateById(item);
    }

    @Override
    public void remove(Long userId, Long cartItemId) {
        CartItem item = cartItemMapper.selectById(cartItemId);
        if (item == null || !item.getUserId().equals(userId)) throw new BizException("购物车项不存在");
        cartItemMapper.deleteById(cartItemId);
    }

    @Override
    public void clear(Long userId) {
        cartItemMapper.delete(new LambdaQueryWrapper<CartItem>().eq(CartItem::getUserId, userId));
    }
}
