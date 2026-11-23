package com.smarthome.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.entity.OperationLog;
import com.smarthome.mapper.OperationLogMapper;
import com.smarthome.service.OperationLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class OperationLogServiceImpl implements OperationLogService {

    private final OperationLogMapper operationLogMapper;

    @Override
    public void record(OperationLog item) {
        operationLogMapper.insert(item);
    }

    @Override
    public List<OperationLog> latest(int limit) {
        // 防御性钳制：最少 1 条、最多 200 条
        int safe = Math.min(Math.max(limit, 1), 200);
        return operationLogMapper.selectList(new LambdaQueryWrapper<OperationLog>()
                .orderByDesc(OperationLog::getId)
                .last("LIMIT " + safe));
    }
}
