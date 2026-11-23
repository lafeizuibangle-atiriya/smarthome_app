package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.dto.CartAddDTO;
import com.smarthome.service.CartService;
import com.smarthome.vo.CartItemVO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/cart")
@RequiredArgsConstructor
public class CartController {

    private final CartService cartService;

    @PostMapping
    public Result<Void> add(@Valid @RequestBody CartAddDTO dto, HttpServletRequest request) {
        cartService.add(userId(request), dto.getGoodsId(), dto.getQuantity());
        return Result.ok();
    }

    @GetMapping("/list")
    public Result<List<CartItemVO>> list(HttpServletRequest request) {
        return Result.ok(cartService.list(userId(request)));
    }

    /** 修改数量：body {"id":1,"quantity":3} */
    @PutMapping
    public Result<Void> update(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        Object id = body.get("id");
        Object quantity = body.get("quantity");
        if (id == null || quantity == null) return Result.error(400, "购物车项 id 与数量都不能为空");
        cartService.updateQuantity(userId(request), Long.valueOf(id.toString()),
                Integer.valueOf(quantity.toString()));
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id, HttpServletRequest request) {
        cartService.remove(userId(request), id);
        return Result.ok();
    }

    @DeleteMapping("/clear")
    public Result<Void> clear(HttpServletRequest request) {
        cartService.clear(userId(request));
        return Result.ok();
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
