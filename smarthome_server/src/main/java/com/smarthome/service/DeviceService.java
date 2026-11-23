package com.smarthome.service;

import com.smarthome.common.PageVO;
import com.smarthome.dto.DeviceAddDTO;
import com.smarthome.dto.RoomEnvDTO;
import com.smarthome.entity.DeviceLog;
import com.smarthome.entity.Room;
import com.smarthome.vo.DeviceVO;
import com.smarthome.vo.HomeOverviewVO;
import com.smarthome.vo.RoomEnvironmentVO;

import java.util.List;
import java.util.Map;

/** 设备 + 房间 + 环境监测模块（核心，手册第四章）。 */
public interface DeviceService {
    // ---------- 设备 ----------
    List<DeviceVO> listByRoom(Long roomId, Long userId);
    DeviceVO detail(Long deviceId, Long userId);
    HomeOverviewVO overview(Long userId);
    DeviceVO control(Long deviceId, Long userId, Map<String, Object> action);

    /** 全屋模式切换（2026-11-20 新增）：mode = AUTO / MANUAL，下发华为云并写 system_config */
    String setMode(String mode, Long userId);
    void add(DeviceAddDTO dto, Long userId);
    void remove(Long deviceId, Long userId);
    void rename(Long deviceId, Long userId, String name);
    List<DeviceLog> logs(Long deviceId, Long userId);

    /** 设备操作日志分页版（2026-11-23 后端增强） */
    PageVO<DeviceLog> logsPage(Long deviceId, Long userId, int pageNum, int pageSize);

    // ---------- 房间（与设备/环境同属一个业务域，方法集中在此） ----------
    List<Room> roomList(Long userId);
    void addRoom(String name, Long userId);
    void renameRoom(Long roomId, Long userId, String name);
    void removeRoom(Long roomId, Long userId);

    // ---------- 环境监测（2026-11-19 对齐硬件：温湿度 + 光照，仅阳台） ----------
    RoomEnvironmentVO environment(Long roomId, Long userId);
    RoomEnvironmentVO refreshEnvironment(Long roomId, Long userId, RoomEnvDTO dto);
    List<Map<String, String>> envMetrics();

    // ---------- 通用设备定时开关 ----------
    /** 扫描所有设备的 timerOn / timerOff，到点执行开/关。返回触发台数 */
    int runDeviceTimers();

    // ---------- 字典 ----------
    List<Map<String, Object>> types();
}
