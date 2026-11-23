package com.smarthome.task;

import com.smarthome.config.HuaweiIoTProperties;
import com.smarthome.service.HuaweiIoTClient;
import com.smarthome.service.HuaweiSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.Map;

/**
 * 华为云 REST 轮询任务（上行的"回退"方案，2026-11-19 降级为备用）。
 *
 * <p>【主方案是 AMQP 推送】HuaweiAmqpClient 配好 AMQP 凭证后本任务每圈直接跳过——
 * 推送模式下平台主动把设备上报推过来，不需要再轮询 REST 接口，服务器零压力。
 * <p>【回退场景】只填了 IAM 凭证、没填 AMQP 凭证（isReady 且 !isAmqpReady）时，
 * 本任务每 3 秒查一次设备属性，保证功能可用；之后再补 AMQP 凭证就自动切推送。
 * <p>写库逻辑在 HuaweiSyncService，本类只负责触发。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class HuaweiSyncTask {

    private final HuaweiIoTProperties props;
    private final HuaweiIoTClient client;
    private final HuaweiSyncService syncService;

    @Scheduled(fixedDelay = 3000, initialDelay = 10000)
    public void poll() {
        if (!props.isReady() || props.isAmqpReady()) {
            return;     // 凭证未配，或已切 AMQP 推送模式：轮询停用
        }

        Map<String, Object> properties = client.queryProperties();
        if (properties == null) {
            return;     // 离线 / 凭证问题已在 client 里打过日志
        }
        syncService.syncProperties(properties);
    }
}
