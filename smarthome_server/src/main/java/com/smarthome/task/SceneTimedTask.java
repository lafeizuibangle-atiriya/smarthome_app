package com.smarthome.task;

import com.smarthome.service.SceneService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 【阶段③】定时场景扫描任务（手册 4.5 / 5 章）。
 * @Scheduled(cron = "0 * * * * ?") 每分钟整点调一次 sceneService.runTimedScenes()。
 * 自动化的 cron_expr 字段存 "HH:mm" 字符串，业务层拿当前 HH:mm 与之比对即可，够 Demo 用。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SceneTimedTask {

    private final SceneService sceneService;

    @Scheduled(cron = "0 * * * * ?")
    public void run() {
        try {
            sceneService.runTimedScenes();
        } catch (Exception e) {
            log.warn("[定时场景] 扫描任务异常：{}", e.getMessage());
        }
    }
}
