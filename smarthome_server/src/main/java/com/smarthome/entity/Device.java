package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 设备表 device（模拟设备）。
 * type 共 6 种：light / ac / socket / curtain / pump(浇花水泵) / lock(门禁)
 *   —— temp_sensor(温湿度计) 已于 2026-09 移除，环境数据改由 room_environment 表承担！
 *
 * status 是 JSON 字符串，不同类型字段不同（2026-09-23 扩展了可调基础功能）：
 *
 *   通用： `{"timerOn":"","timerOff":""}` —— 每日定时开 / 关，格式 "HH:mm"，空串=不定时，
 *          由 DeviceTimedTask 每分钟扫描执行（对 6 种类型都生效）。
 *
 *   light:   {"power":"on","brightness":80,"colorTemp":4000}
 *            · brightness 1-100；colorTemp 仅 2700(暖光) / 4000(自然) / 6500(冷白)
 *   ac:      {"power":"on","temperature":26,"mode":"cool","fanSpeed":2,"swing":0}
 *            · temperature 16-30；mode = cool 制冷 / heat 制热 / dry 除湿 / fan 送风 / auto 自动
 *            · fanSpeed 0 自动 / 1 低 / 2 中 / 3 高；swing 0 关 / 1 上下 / 2 左右 / 3 上下+左右
 *   socket:  {"power":"off","ratedW":300,"powerW":0,"energyKwh":0}
 *            · ratedW 额定功率(W)；powerW / energyKwh 是**只读**字段，由 DeviceTimedTask 按分钟计量
 *   curtain: {"openPercent":50} —— 0-100，0 即关机；power 由后端联动（0=off，>0=on）
 *   pump:    {"power":"off","watering":0,"duration":10,"waterLevel":80,"waterPlan":"",
 *             "waterStartLevel":80,"waterStartTime":"","waterEndTime":""}
 *            水量 waterLevel **不可手动设置**：开泵记 waterStartLevel/waterStartTime，
 *            之后剩余 = 开浇水位 - 已浇分钟数（1%/分钟，WaterTimedTask 每分钟推进）
 *   lock:    {"power":"off","locked":1,"battery":92,"keepOpen":0,"lastUser":"","lastTime":""}
 *            · locked 1 上锁 / 0 开锁（power **反向**联动）；keepOpen=1 常开模式会自动开锁
 *            · battery / lastUser / lastTime 是设备上报的**只读**字段
 *
 * 【控制指令的"什么能改、能改成多少"】统一由 DeviceServiceImpl.sanitizeAction 定义：
 * 只读字段一律丢弃、枚举字段走白名单、数值字段越界直接报错。
 *
 * 【驼峰映射】数据库下划线 create_time ↔ Java createTime，mybatis-plus 已全局配置。
 */
@Data
@TableName("device")
public class Device {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long roomId;
    private String name;
    private String type;        // light / ac / socket / curtain / pump / lock
    private String status;      // JSON 字符串
    private Integer online;     // 1 在线 / 0 离线
    private LocalDateTime createTime;
}
