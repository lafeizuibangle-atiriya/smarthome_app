package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 全局操作日志表 operation_log（AOP 切面 OpLogAspect 自动写入）。
 * userId = 0 表示未登录触发的放行接口；detail 已做脱敏+截断 200 字。
 */
@Data
@TableName("operation_log")
public class OperationLog {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String module;
    private String action;
    private String detail;
    private LocalDateTime createTime;
}
