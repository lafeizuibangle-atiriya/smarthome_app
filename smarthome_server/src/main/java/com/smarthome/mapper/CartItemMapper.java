package com.smarthome.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.smarthome.entity.CartItem;
import com.smarthome.vo.CartItemVO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface CartItemMapper extends BaseMapper<CartItem> {

    /** 购物车列表要显示商品最新名称/价格/图片，所以联表查 */
    @Select("""
            SELECT c.id, c.goods_id AS goodsId, g.name AS goodsName, g.cover AS goodsCover,
                   g.price, c.quantity
            FROM cart_item c
            JOIN goods g ON c.goods_id = g.id
            WHERE c.user_id = #{userId}
            ORDER BY c.create_time DESC
            """)
    List<CartItemVO> selectCartWithGoods(Long userId);
}
