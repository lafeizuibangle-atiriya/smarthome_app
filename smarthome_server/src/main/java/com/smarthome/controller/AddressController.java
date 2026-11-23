package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.dto.AddressDTO;
import com.smarthome.entity.Address;
import com.smarthome.service.AddressService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/address")
@RequiredArgsConstructor
public class AddressController {

    private final AddressService addressService;

    @GetMapping("/list")
    public Result<List<Address>> list(HttpServletRequest request) {
        return Result.ok(addressService.list(userId(request)));
    }

    @PostMapping
    public Result<Void> add(@Valid @RequestBody AddressDTO dto, HttpServletRequest request) {
        addressService.add(userId(request), dto);
        return Result.ok();
    }

    @PutMapping
    public Result<Void> update(@Valid @RequestBody AddressDTO dto, HttpServletRequest request) {
        addressService.update(userId(request), dto);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id, HttpServletRequest request) {
        addressService.remove(userId(request), id);
        return Result.ok();
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
