package com.smarthome.controller;

import com.smarthome.common.PageVO;
import com.smarthome.common.Result;
import com.smarthome.dto.OrderCreateDTO;
import com.smarthome.service.OrderService;
import com.smarthome.vo.OrderVO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/order")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    /** 提交订单：requestId 为幂等键（同一 requestId 重复提交只下一单），2026-11-23 */
    @PostMapping("/create")
    public Result<OrderVO> create(@Valid @RequestBody OrderCreateDTO dto, HttpServletRequest request) {
        return Result.ok(orderService.create(userId(request), dto));
    }

    /** 订单列表分页版（2026-11-23）：GET /api/order/page?status=-1&pageNum=1&pageSize=10 */
    @GetMapping("/page")
    public Result<PageVO<OrderVO>> page(@RequestParam(required = false, defaultValue = "-1") Integer status,
                                        @RequestParam(required = false, defaultValue = "1") Integer pageNum,
                                        @RequestParam(required = false, defaultValue = "10") Integer pageSize,
                                        HttpServletRequest request) {
        return Result.ok(orderService.page(userId(request), status, pageNum, pageSize));
    }

    @PostMapping("/{id}/pay")
    public Result<Void> pay(@PathVariable Long id, HttpServletRequest request) {
        orderService.pay(id, userId(request));
        return Result.ok();
    }

    @PostMapping("/{id}/cancel")
    public Result<Void> cancel(@PathVariable Long id, HttpServletRequest request) {
        orderService.cancel(id, userId(request));
        return Result.ok();
    }

    @GetMapping("/list")
    public Result<List<OrderVO>> list(@RequestParam(required = false) Integer status,
                                      HttpServletRequest request) {
        return Result.ok(orderService.list(userId(request), status));
    }

    @GetMapping("/{id}")
    public Result<OrderVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(orderService.detail(id, userId(request)));
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
