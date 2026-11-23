-- ============================================================
-- 存量库升级脚本 v2：环境精简 + 自动门 + 每房间有设备（2026-11-19）
-- 用途：跑过 upgrade_align_hardware.sql 的环境，增量升级到最新形态。
-- 变更：
--   1) 房间"卫生间"改回"阳台"（环境传感器约定放阳台）；
--   2) room_environment 加 lux 列（旧列 aqi/co2/gas 等废弃，保留不删）；
--   3) "客厅道闸"改名为"客厅自动门"（Servo_control 命令不变）；
--   4) 新增 卧室-人体感应(pir_sensor) / 阳台-环境检测(env_sensor) 两台只读设备；
--   5) 烟雾传感器状态结构更新（smoke 展示值 + alarm 报警位，阈值在固件烧死）；
--   6) 场景描述文案同步（道闸→自动门）。
-- 注意：device id 6/7 是新增的，scene_action 不引用它们，追加在末尾安全。
-- ============================================================

USE smart_home;

-- 1) 房间改名
UPDATE room SET name = '阳台' WHERE name = '卫生间';

-- 2) 环境表加 lux 列（已存在会报错，忽略即可）
ALTER TABLE room_environment ADD COLUMN lux DOUBLE NULL AFTER humidity;

-- 3) 道闸 → 自动门
UPDATE device SET name = '客厅自动门' WHERE type = 'gate';

-- 4) 新增两台只读设备（卧室 / 阳台，保证每个房间都有设备）
INSERT INTO device (room_id, name, type, status)
SELECT id, '人体感应', 'pir_sensor', '{"present":"off"}' FROM room WHERE name = '卧室' LIMIT 1;
INSERT INTO device (room_id, name, type, status)
SELECT id, '环境检测', 'env_sensor', '{"temperature":0,"humidity":0,"lux":0}' FROM room WHERE name = '阳台' LIMIT 1;

-- 5) 烟雾传感器状态结构更新
UPDATE device SET status = '{"power":"on","smoke":6,"alarm":0,"battery":100,"timerOn":"","timerOff":""}'
WHERE type = 'smoke_sensor';

-- 6) 场景文案同步
UPDATE scene SET description = '自动门开门放行、客厅灯亮起，进门就是亮堂状态' WHERE name = '回家模式';
UPDATE scene SET description = '自动门关门、全屋灯和风扇关闭、蜂鸣器静音' WHERE name = '离家模式';
