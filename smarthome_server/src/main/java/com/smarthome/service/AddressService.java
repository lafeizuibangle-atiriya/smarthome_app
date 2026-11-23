package com.smarthome.service;

import com.smarthome.dto.AddressDTO;
import com.smarthome.entity.Address;

import java.util.List;

/** 收货地址模块（接口文档三）。 */
public interface AddressService {
    List<Address> list(Long userId);
    void add(Long userId, AddressDTO dto);
    void update(Long userId, AddressDTO dto);
    void remove(Long userId, Long addressId);
}
