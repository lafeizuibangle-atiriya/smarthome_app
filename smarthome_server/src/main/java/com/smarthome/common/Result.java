package com.smarthome.common;

import lombok.Data;

/**
 * 统一返回体（《02_开发手册_后端.md》2.1 节）。所有 Controller 的返回值一律用它包装。
 * 前端契约：{ code, msg, data }，code=200 成功 / 400 业务错 / 401 未登录 / 500 系统错。
 */
@Data
public class Result<T> {
    private int code;
    private String msg;
    private T data;

    public static <T> Result<T> ok(T data) {
        Result<T> r = new Result<>();
        r.code = 200;
        r.msg = "success";
        r.data = data;
        return r;
    }

    public static <T> Result<T> ok() {
        return ok(null);
    }

    public static <T> Result<T> error(int code, String msg) {
        Result<T> r = new Result<>();
        r.code = code;
        r.msg = msg;
        return r;
    }
}
