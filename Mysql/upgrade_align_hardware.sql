-- ============================================================
-- 存量库升级脚本：设备清单对齐硬件（2026-11-19）
-- 用途：已按 init_all.sql 建过库的环境，不用整库重装，跑这一份即可。
-- 效果：设备清空重建为 5 台（客厅灯/客厅风扇/客厅道闸/烟雾传感器/厨房蜂鸣器），
--       场景重建为 3 个（回家/离家/晚安），房间"阳台"改名为"卫生间"。
-- 注意：device_log 里的历史操作记录会一并清空（旧设备已不存在，记录无意义）。
-- ============================================================

USE smart_home;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE scene_action;
TRUNCATE TABLE scene;
TRUNCATE TABLE device_log;
TRUNCATE TABLE device;
SET FOREIGN_KEY_CHECKS = 1;

-- 房间"阳台"改为"卫生间"，与实训箱分区一致（user_id=1 为演示用户）
UPDATE room SET name = '卫生间' WHERE name = '阳台';

-- 5 台设备（id 1~5，scene_action 引用这些 id；新增设备必须追加在末尾）
INSERT INTO device (room_id, name, type, status) VALUES
(1, '客厅灯',       'light',        '{"power":"off","brightness":80,"colorTemp":4000,"timerOn":"","timerOff":""}'),
(1, '客厅风扇',     'fan',          '{"power":"off","timerOn":"","timerOff":""}'),
(1, '客厅道闸',     'gate',         '{"power":"off","timerOn":"","timerOff":""}'),
(3, '烟雾传感器',   'smoke_sensor', '{"power":"on","smoke":3,"battery":100,"smokeLimit":50,"timerOn":"","timerOff":""}'),
(3, '厨房蜂鸣器',   'beep',         '{"power":"off","timerOn":"","timerOff":""}');

-- 3 个预设场景
INSERT INTO scene (id, user_id, name, icon, description, trigger_type, cron_expr, enabled) VALUES
(1, 1, '回家模式', 'home', '道闸抬杆放行、客厅灯亮起，进门就是亮堂状态', 'MANUAL', NULL, 1),
(2, 1, '离家模式', 'away', '道闸落杆、全屋灯和风扇关闭、蜂鸣器静音', 'MANUAL', NULL, 1),
(3, 1, '晚安模式', 'night', '每晚 23:00 自动关灯、蜂鸣器静音，安心入睡', 'TIMER', '23:00', 1);

INSERT INTO scene_action (scene_id, device_id, action) VALUES
(1, 3, '{"power":"on"}'), (1, 1, '{"power":"on","brightness":100}'),
(2, 3, '{"power":"off"}'), (2, 1, '{"power":"off"}'),
(2, 2, '{"power":"off"}'), (2, 5, '{"power":"off"}'),
(3, 1, '{"power":"off"}'), (3, 5, '{"power":"off"}');
