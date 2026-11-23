package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.entity.OperationLog;
import com.smarthome.service.OperationLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** 操作日志查询：看「谁做了什么」。 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class OpLogController {

    private final OperationLogService operationLogService;

    /** 最近操作日志，limit 可选（默认 100，最多 200），新的在前 */
    @GetMapping("/oplog/list")
    public Result<List<OperationLog>> list(@RequestParam(defaultValue = "100") int limit) {
        return Result.ok(operationLogService.latest(limit));
    }
}
