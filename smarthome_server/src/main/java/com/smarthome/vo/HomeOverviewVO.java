package com.smarthome.vo;

import com.smarthome.entity.Room;
import lombok.Data;
import java.util.List;

/** 首页一次拿全：房间 + 设备 + 每个房间的环境数据（等长同序）+ 全屋告警数。 */
@Data
public class HomeOverviewVO {
    private String homeName;
    private List<Room> rooms;
    private List<DeviceVO> devices;
    /**
     * 每个房间的环境监测数据，与 rooms 等长同序（下标一一对应）。
     */
    private List<RoomEnvironmentVO> environments;
    /** 全屋告警合计，>0 时首页顶部提示"⚠ 有告警" */
    private Integer alarmCount;
    /** 全屋自动/手动模式（2026-11-20 新增）：AUTO / MANUAL，与硬件 ModeStatus 同步 */
    private String mode;
}
