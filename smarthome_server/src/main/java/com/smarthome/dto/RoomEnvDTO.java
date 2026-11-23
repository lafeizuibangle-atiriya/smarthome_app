package com.smarthome.dto;

import lombok.Data;

/**
 * 手动刷新环境的入参（POST /api/room/{roomId}/environment/refresh 的请求体）。
 * 字段全部可空：字段为 null = 该项随机波动；非 null = 直接覆盖（演示一键造报警，如 {"gas":350}）。
 * Controller 上必须写 @RequestBody(required = false)，否则空 body 直接 400。
 */
@Data
public class RoomEnvDTO {
    private Double temperature;
    private Integer humidity;
    private Integer aqi;
    private Integer co2;
    private Integer smoke;
    private Integer gas;
    private Integer hasGas;     // 1/0，用来现场演示"把这个房间改成支持燃气检测"
}
