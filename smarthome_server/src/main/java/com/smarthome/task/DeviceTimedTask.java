package com.smarthome.task;

import com.smarthome.service.DeviceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 通用设备定时开关（2026-09-23 新增；2026-11-19 随设备清单精简，
 * 移除插座计量与家电运行态推进 —— 对应的模拟设备已删除）。
 *
 * <p>@Scheduled(cron = "0 * * * * ?") 每分钟第 0 秒跑一次：
 * {@code deviceService.runDeviceTimers()} —— 扫描所有设备的 timerOn / timerOff，
 * 到点就执行"开 / 关"（power on/off），返回触发台数。
 *
 * <p>【为什么整段 try-catch】定时任务里抛出异常会静默终止后续调度 ——
 * 一次脏数据就能让整个定时体系停摆。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DeviceTimedTask {

    private final DeviceService deviceService;

    @Scheduled(cron = "0 * * * * ?")
    public void run() {
        try {
            int fired = deviceService.runDeviceTimers();
            if (fired > 0) {
                log.info("[设备定时] 本轮按时触发的设备 {} 台", fired);
            }
        } catch (Exception e) {
            log.warn("[设备定时] 定时开关任务异常：{}", e.getMessage());
        }
    }
}
