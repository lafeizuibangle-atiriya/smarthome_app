package com.smarthome.service;

import com.smarthome.entity.OperationLog;

import java.util.List;

public interface OperationLogService {

    /** 保存一条操作日志（切面调用；内部已兜底，失败不影响业务） */
    void record(OperationLog item);

    /** 最近操作日志，新的在前，最多取 limit 条 */
    List<OperationLog> latest(int limit);
}
