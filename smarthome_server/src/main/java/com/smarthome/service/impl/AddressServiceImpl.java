package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.dto.AddressDTO;
import com.smarthome.entity.Address;
import com.smarthome.mapper.AddressMapper;
import com.smarthome.service.AddressService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AddressServiceImpl implements AddressService {

    private final AddressMapper addressMapper;

    @Override
    public List<Address> list(Long userId) {
        return addressMapper.selectList(new LambdaQueryWrapper<Address>()
                .eq(Address::getUserId, userId)
                .orderByDesc(Address::getIsDefault)
                .orderByDesc(Address::getId));
    }

    @Override
    public void add(Long userId, AddressDTO dto) {
        checkInput(dto);
        Address address = new Address();
        copy(dto, address);
        address.setUserId(userId);
        if (Integer.valueOf(1).equals(dto.getIsDefault())) {
            clearDefault(userId);
        }
        addressMapper.insert(address);
    }

    @Override
    public void update(Long userId, AddressDTO dto) {
        if (dto.getId() == null) throw new BizException("缺少地址 id");
        Address address = addressMapper.selectById(dto.getId());
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("地址不存在");
        }
        checkInput(dto);
        copy(dto, address);
        if (Integer.valueOf(1).equals(dto.getIsDefault())) {
            clearDefault(userId);
        }
        addressMapper.updateById(address);
    }

    @Override
    public void remove(Long userId, Long addressId) {
        Address address = addressMapper.selectById(addressId);
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("地址不存在");
        }
        addressMapper.deleteById(addressId);
    }

    private void checkInput(AddressDTO dto) {
        if (dto.getReceiver() == null || dto.getReceiver().isEmpty()) throw new BizException("请填写收货人");
        if (dto.getPhone() == null || dto.getPhone().isEmpty()) throw new BizException("请填写手机号");
        if (dto.getRegion() == null || dto.getRegion().isEmpty()) throw new BizException("请填写省市区");
        if (dto.getDetail() == null || dto.getDetail().isEmpty()) throw new BizException("请填写详细地址");
    }

    private void copy(AddressDTO dto, Address address) {
        address.setReceiver(dto.getReceiver());
        address.setPhone(dto.getPhone());
        address.setRegion(dto.getRegion());
        address.setDetail(dto.getDetail());
        address.setIsDefault(dto.getIsDefault() == null ? 0 : dto.getIsDefault());
    }

    private void clearDefault(Long userId) {
        List<Address> defaults = addressMapper.selectList(new LambdaQueryWrapper<Address>()
                .eq(Address::getUserId, userId).eq(Address::getIsDefault, 1));
        for (Address item : defaults) {
            item.setIsDefault(0);
            addressMapper.updateById(item);
        }
    }
}
