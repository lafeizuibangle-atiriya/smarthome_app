package com.smarthome.common;

/**
 * 业务异常（手册 2.2 节）：Service 里只管 throw new BizException("提示语")，
 * 不用 try-catch —— 统一由 GlobalExceptionHandler 转成 code=400 的 Result 给前端。
 */
public class BizException extends RuntimeException {
    public BizException(String message) {
        super(message);
    }
}
