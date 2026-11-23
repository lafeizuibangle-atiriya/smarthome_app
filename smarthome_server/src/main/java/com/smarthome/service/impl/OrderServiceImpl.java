package com.smarthome.service.impl;

import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.smarthome.common.BizException;
import com.smarthome.common.PageVO;
import com.smarthome.dto.OrderCreateDTO;
import com.smarthome.entity.*;
import com.smarthome.mapper.*;
import com.smarthome.service.OrderService;
import com.smarthome.vo.OrderVO;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class OrderServiceImpl implements OrderService {

    private final OrdersMapper orderMapper;
    private final OrderItemMapper orderItemMapper;
    private final GoodsMapper goodsMapper;
    private final AddressMapper addressMapper;
    private final CartItemMapper cartItemMapper;
    private final StringRedisTemplate stringRedisTemplate;   // 下单接口幂等（2026-11-23）

    /**
     * 提交订单。一个事务里做四件事：
     * 1) 校验商品与库存  2) 扣库存/加销量  3) 生成订单与订单项  4) 清空购物车里已下单的商品
     * 任何一步失败整体回滚，避免"扣了库存却没有订单"。
     *
     * <p>【接口幂等（2026-11-23）】客户端传 requestId 时启用幂等保护：
     * Redis SETNX 占位 → 只有第一次请求真正下单 → 执行结果缓存 10 分钟；
     * 同一 requestId 的重复提交（网络重试、用户连点）直接返回第一次的订单。
     * 下单失败会释放占位，允许用同一 requestId 重试。
     * 不传 requestId 则按旧行为直接下单（兼容旧客户端）。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public OrderVO create(Long userId, OrderCreateDTO dto) {
        if (dto == null || dto.getItems() == null || dto.getItems().isEmpty()) {
            throw new BizException("请选择要购买的商品");
        }

        String idemKey = null;
        if (dto.getRequestId() != null && !dto.getRequestId().isBlank()) {
            idemKey = "order:idem:" + userId + ":" + dto.getRequestId();
            // SETNX：第一个到达的请求占住坑位（1 分钟过期，防异常中断后永久锁死）
            Boolean first = stringRedisTemplate.opsForValue()
                    .setIfAbsent(idemKey, "processing", Duration.ofMinutes(1));
            if (Boolean.FALSE.equals(first)) {
                // 坑位被占：要么上次请求已完成（返回缓存结果），要么正在处理中
                String cached = stringRedisTemplate.opsForValue().get(idemKey + ":result");
                if (cached != null) {
                    return JSONUtil.toBean(cached, OrderVO.class);
                }
                throw new BizException("订单正在处理中，请勿重复提交");
            }
        }

        try {
            OrderVO vo = doCreate(userId, dto.getAddressId(), dto.getItems());
            if (idemKey != null) {
                // 结果缓存 10 分钟：期间同一 requestId 的重试都返回这单
                stringRedisTemplate.opsForValue()
                        .set(idemKey + ":result", JSONUtil.toJsonStr(vo), Duration.ofMinutes(10));
            }
            return vo;
        } catch (Exception e) {
            // 下单失败释放占位，允许客户端用同一 requestId 重试
            if (idemKey != null) {
                stringRedisTemplate.delete(idemKey);
            }
            throw e;
        }
    }

    private OrderVO doCreate(Long userId, Long addressId, List<Map<String, Object>> items) {
        Address address = addressMapper.selectById(addressId);
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("收货地址无效");
        }

        BigDecimal total = BigDecimal.ZERO;             // 金额用 BigDecimal，绝不用 double
        List<OrderItem> orderItems = new ArrayList<>();

        for (Map<String, Object> item : items) {
            Long goodsId = Long.valueOf(item.get("goodsId").toString());
            Integer quantity = Integer.valueOf(item.get("quantity").toString());

            Goods goods = goodsMapper.selectById(goodsId);
            if (goods == null) throw new BizException("商品不存在");
            if (goods.getStock() < quantity) throw new BizException(goods.getName() + " 库存不足");

            // 扣库存、加销量
            goods.setStock(goods.getStock() - quantity);
            goods.setSales(goods.getSales() + quantity);
            goodsMapper.updateById(goods);

            // 订单项保存商品快照
            OrderItem orderItem = new OrderItem();
            orderItem.setGoodsId(goodsId);
            orderItem.setGoodsName(goods.getName());
            orderItem.setGoodsCover(goods.getCover());
            orderItem.setPrice(goods.getPrice());
            orderItem.setQuantity(quantity);
            orderItems.add(orderItem);

            total = total.add(goods.getPrice().multiply(BigDecimal.valueOf(quantity)));
        }

        // 生成订单主表
        Orders order = new Orders();
        order.setOrderNo(generateOrderNo());
        order.setUserId(userId);
        order.setAddressId(addressId);
        order.setTotalAmount(total);
        order.setStatus(0);                          // 0 待付款
        order.setReceiverName(address.getReceiver());
        order.setReceiverPhone(address.getPhone());
        order.setReceiverAddress((address.getRegion() == null ? "" : address.getRegion())
                + " " + (address.getDetail() == null ? "" : address.getDetail()));
        order.setCreateTime(LocalDateTime.now());
        orderMapper.insert(order);

        // 生成订单项（此时才有 orderId）
        for (OrderItem orderItem : orderItems) {
            orderItem.setOrderId(order.getId());
            orderItemMapper.insert(orderItem);
        }

        // 清掉购物车里已下单的商品
        List<Long> goodsIds = orderItems.stream().map(OrderItem::getGoodsId).toList();
        cartItemMapper.delete(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .in(CartItem::getGoodsId, goodsIds));

        return detail(order.getId(), userId);
    }

    /**
     * 模拟支付：真实项目这里等支付平台回调，Demo 直接把状态改为"已付款"。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void pay(Long orderId, Long userId) {
        Orders order = orderMapper.selectById(orderId);
        if (order == null || !order.getUserId().equals(userId)) throw new BizException("订单不存在");
        if (order.getStatus() != 0) throw new BizException("该订单当前状态不可支付");

        order.setStatus(1);                          // 1 已付款
        order.setPayTime(LocalDateTime.now());
        orderMapper.updateById(order);
    }

    /**
     * 取消订单：把库存加回去，保证数据一致。
     * 允许取消待付款(0)/已付款(1)订单（已付款取消等同退款，库存回滚）；已完成/已取消不再处理。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long orderId, Long userId) {
        Orders order = orderMapper.selectById(orderId);
        if (order == null || !order.getUserId().equals(userId)) throw new BizException("订单不存在");
        if (order.getStatus() == 2 || order.getStatus() == 3) {
            throw new BizException("该订单当前状态不可取消");
        }

        List<OrderItem> items = orderItemMapper.selectList(
                new LambdaQueryWrapper<OrderItem>().eq(OrderItem::getOrderId, orderId));
        for (OrderItem item : items) {
            Goods goods = goodsMapper.selectById(item.getGoodsId());
            if (goods != null) {
                goods.setStock(goods.getStock() + item.getQuantity());
                goodsMapper.updateById(goods);
            }
        }
        order.setStatus(3);                          // 3 已取消
        orderMapper.updateById(order);
    }

    @Override
    public List<OrderVO> list(Long userId, Integer status) {
        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<Orders>()
                .eq(Orders::getUserId, userId)
                .orderByDesc(Orders::getCreateTime);
        if (status != null && status >= 0) {         // -1 表示全部
            wrapper.eq(Orders::getStatus, status);
        }
        List<OrderVO> result = new ArrayList<>();
        for (Orders order : orderMapper.selectList(wrapper)) {
            result.add(detail(order.getId(), userId));
        }
        return result;
    }

    /**
     * 订单列表分页版（2026-11-23 后端增强）。
     * 分页插件对订单主表做物理分页（LIMIT），订单项仍按订单逐个取；
     * pageSize 上限 50，防恶意大页一次拉爆内存。
     */
    @Override
    public PageVO<OrderVO> page(Long userId, Integer status, int pageNum, int pageSize) {
        if (pageNum < 1) pageNum = 1;
        pageSize = Math.min(Math.max(pageSize, 1), 50);

        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<Orders>()
                .eq(Orders::getUserId, userId)
                .orderByDesc(Orders::getCreateTime);
        if (status != null && status >= 0) {         // -1 表示全部
            wrapper.eq(Orders::getStatus, status);
        }

        Page<Orders> page = orderMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        List<OrderVO> result = new ArrayList<>();
        for (Orders order : page.getRecords()) {
            result.add(detail(order.getId(), userId));
        }
        return PageVO.of(result, page.getTotal(), page.getCurrent(), page.getSize());
    }

    @Override
    public OrderVO detail(Long orderId, Long userId) {
        Orders order = orderMapper.selectById(orderId);
        if (order == null) throw new BizException("订单不存在");
        if (!order.getUserId().equals(userId)) throw new BizException("无权查看该订单");

        OrderVO vo = new OrderVO();
        vo.setId(order.getId());
        vo.setOrderNo(order.getOrderNo());
        vo.setTotalAmount(order.getTotalAmount());
        vo.setStatus(order.getStatus());
        vo.setCreateTime(order.getCreateTime());
        vo.setReceiverName(order.getReceiverName());
        vo.setReceiverPhone(order.getReceiverPhone());
        vo.setReceiverAddress(order.getReceiverAddress());
        vo.setItems(orderItemMapper.selectList(
                new LambdaQueryWrapper<OrderItem>().eq(OrderItem::getOrderId, orderId)));
        return vo;
    }

    /** 订单号：时间戳 + 3 位随机数 */
    private String generateOrderNo() {
        String time = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        int random = new Random().nextInt(900) + 100;
        return time + random;
    }
}
