package com.smarthome;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 启动类。
 * 【必写】@EnableScheduling：不加的话环境模拟 / 定时场景 / 定时浇水三个定时任务全部不执行。
 * 【红线】同一时间只允许启动一个后端实例——两个进程同时写库会导致
 *         环境数值双倍跳动、定时场景重复执行、水泵水量双倍扣减（总方案踩坑 4）。
 */
@SpringBootApplication
@EnableScheduling
public class SmartHomeApplication {
    public static void main(String[] args) {
        SpringApplication.run(SmartHomeApplication.class, args);
    }
}
