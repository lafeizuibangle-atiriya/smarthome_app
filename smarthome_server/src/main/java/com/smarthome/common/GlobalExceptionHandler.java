package com.smarthome.common;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 全局异常处理（手册 2.3 节，2026-11-23 后端增强）。
 * 原则：业务异常原样给前端；参数校验异常转成 400 + 具体字段提示；
 * 其他异常只记日志，不把堆栈和内部细节暴露给客户端。
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** 业务异常：把提示语原样给前端（如"库存不足"） */
    @ExceptionHandler(BizException.class)
    public Result<Void> handleBiz(BizException e) {
        return Result.error(400, e.getMessage());
    }

    /**
     * 参数校验异常（@Valid + DTO 上的 @NotBlank/@Min/@Email 等，2026-11-23 新增）。
     * 把第一条校验失败信息返回给前端，形如"password：密码不能为空"。
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValid(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
                .findFirst()
                .map(err -> err.getField() + "：" + err.getDefaultMessage())
                .orElse("参数不合法");
        return Result.error(400, msg);
    }

    /** 请求体不是合法 JSON / 缺请求体（常见于调用方传错 Content-Type） */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public Result<Void> handleNotReadable(HttpMessageNotReadableException e) {
        return Result.error(400, "请求体格式错误");
    }

    /** 兜底：只记日志，不暴露堆栈与内部消息（防信息泄露，2026-11-23 收紧） */
    @ExceptionHandler(Exception.class)
    public Result<Void> handleOther(Exception e) {
        log.error("系统异常", e);
        return Result.error(500, "服务器繁忙，请稍后重试");
    }
}
