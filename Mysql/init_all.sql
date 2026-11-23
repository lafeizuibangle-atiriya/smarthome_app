-- =====================================================================
--  智慧家居 App —— 数据库初始化脚本（完整演示数据）
--  技术栈：HarmonyOS(ArkTS) 客户端 + Spring Boot 3.3.4 服务端 + MySQL 8.0
--
--  【本文件说明】
--    自包含脚本，独立执行即可完成：建库 → 建表 → 写入全套演示数据。
--    不依赖任何其它文件。脚本开头带 DROP DATABASE，可反复执行，
--    每次都回到同一套干净的演示数据。
--
--  【演示账号】demo / 123456
--
--  【导入方法】
--    命令行（推荐）——必须带 --default-character-set=utf8mb4，
--    否则中文会全部变成 "?"：
--        mysql -u root -p --default-character-set=utf8mb4 < init_all.sql
--    图形工具（Navicat / MySQL Workbench）：
--        连接字符集设为 utf8mb4，打开本文件直接执行。
--
--  【导入后的数据规模】
--    共 16 张表 · 1 用户 · 4 房间 · 19 台设备（覆盖 17 种设备类型）
--    · 4 条房间环境 · 9 个预设场景 · 8 个产品 · 20 件商品 · 7 张轮播图
--
--  【表清单】
--    user, address, room, device, room_environment
--    device_log, scene, scene_action, product, goods
--    goods_category, cart_item, orders, order_item, operation_log
--    banner
--  【导入后自检】见文件末尾的「自检 SQL」。
-- =====================================================================


DROP DATABASE IF EXISTS smart_home;
CREATE DATABASE smart_home DEFAULT CHARACTER SET utf8mb4;
USE smart_home;

-- ==================== 用户与地址 ====================
CREATE TABLE user (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  username    VARCHAR(100)  NOT NULL UNIQUE COMMENT '账号；邮箱注册用户直接存邮箱，故扩到 100',
  password    VARCHAR(100) NOT NULL,
  nickname    VARCHAR(50),
  avatar      VARCHAR(255),
  email       VARCHAR(64)  NULL UNIQUE COMMENT '邮箱（唯一，不能重复注册）',
  phone       VARCHAR(20)  NULL UNIQUE COMMENT '手机号（唯一，不能重复注册）',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE address (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT NOT NULL,
  receiver   VARCHAR(50) NOT NULL,
  phone      VARCHAR(20) NOT NULL,
  region     VARCHAR(100) COMMENT '省市区',
  detail     VARCHAR(200) COMMENT '详细地址',
  is_default TINYINT DEFAULT 0
);

-- ==================== 设备侧（模拟设备） ====================
CREATE TABLE room (
  id      BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  name    VARCHAR(50) NOT NULL,
  sort    INT DEFAULT 0
);

CREATE TABLE device (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  room_id     BIGINT NOT NULL,
  name        VARCHAR(50) NOT NULL,
  type        VARCHAR(20) NOT NULL COMMENT '7 种：light/fan/gate/beep/smoke_sensor/env_sensor/pir_sensor（对齐实训箱硬件）',
  status      VARCHAR(500) DEFAULT '{}' COMMENT 'JSON 状态（存放该类型的语义字段：开关/温度/亮度/开合度等）',
  online      TINYINT DEFAULT 1,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 房间环境监测：一个房间一条，只保留硬件真实具备的三项（温度/湿度/光照）。
-- 数据来源是华为云上报（HuaweiSyncService 写入），约定归属"阳台"房间；
-- 其他房间没有传感器，三项为 NULL，App 显示"暂无环境检测"。
CREATE TABLE room_environment (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  room_id      BIGINT NOT NULL UNIQUE,
  temperature  DECIMAL(4,1) DEFAULT NULL COMMENT '温度 ℃（SHT30 上报；无传感器为 NULL）',
  humidity     INT DEFAULT NULL COMMENT '湿度 %（SHT30 上报）',
  lux          DOUBLE DEFAULT NULL COMMENT '光照强度 lx（BH1750 上报，0~65535）',
  update_time  DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '最后一次上报时间'
);

CREATE TABLE device_log (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  device_id   BIGINT NOT NULL,
  user_id     BIGINT,
  action      VARCHAR(200),
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE scene (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id      BIGINT NOT NULL,
  name         VARCHAR(50) NOT NULL,
  icon         VARCHAR(50),
  description  VARCHAR(200) COMMENT '场景说明（预设模式卡片展示）',
  trigger_type VARCHAR(20) DEFAULT 'MANUAL' COMMENT 'MANUAL 手动 / TIMER 定时',
  cron_expr    VARCHAR(50) COMMENT '定时时间，格式 HH:mm',
  enabled      TINYINT DEFAULT 1,
  create_time  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE scene_action (
  id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  scene_id  BIGINT NOT NULL,
  device_id BIGINT NOT NULL,
  action    VARCHAR(500) NOT NULL COMMENT '动作 JSON'
);

-- ==================== 产品库（只展示） ====================
CREATE TABLE product (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  name             VARCHAR(100) NOT NULL,
  category         VARCHAR(50),
  cover            VARCHAR(255),
  slogan           VARCHAR(200),
  description      VARCHAR(1000),
  specs            VARCHAR(1000) COMMENT '规格参数 JSON',
  tags             VARCHAR(100),
  related_goods_id BIGINT COMMENT '关联商品 id，用于"去商城看看"'
);

-- ==================== 商城（模拟购买） ====================
CREATE TABLE goods (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id  BIGINT,
  name         VARCHAR(100) NOT NULL,
  cover        VARCHAR(255),
  images       VARCHAR(1000) COMMENT '轮播图 JSON 数组',
  price        DECIMAL(10,2) NOT NULL,
  origin_price DECIMAL(10,2),
  stock        INT DEFAULT 100,
  sales        INT DEFAULT 0,
  detail       VARCHAR(2000),
  tags         VARCHAR(100) COMMENT '搜索标签（逗号分隔），配合 /api/goods/list 三字段搜索',
  status       TINYINT DEFAULT 1 COMMENT '1 上架 0 下架'
);

CREATE TABLE goods_category (
  id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  sort INT DEFAULT 0
);

CREATE TABLE cart_item (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT NOT NULL,
  goods_id    BIGINT NOT NULL,
  quantity    INT DEFAULT 1,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no     VARCHAR(40) NOT NULL UNIQUE,
  user_id      BIGINT NOT NULL,
  address_id   BIGINT,
  total_amount DECIMAL(10,2) NOT NULL,
  status       TINYINT DEFAULT 0 COMMENT '0待付款 1已付款 2已完成 3已取消',
  pay_time     DATETIME,
  create_time  DATETIME DEFAULT CURRENT_TIMESTAMP,
  receiver_name    VARCHAR(50)  COMMENT '收货人快照（下单时从地址复制）',
  receiver_phone   VARCHAR(20)  COMMENT '收货电话快照',
  receiver_address VARCHAR(255) COMMENT '收货地址快照'
);

CREATE TABLE order_item (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id    BIGINT NOT NULL,
  goods_id    BIGINT NOT NULL,
  goods_name  VARCHAR(100) COMMENT '商品名快照',
  goods_cover VARCHAR(255) COMMENT '商品图快照',
  price       DECIMAL(10,2) NOT NULL,
  quantity    INT NOT NULL
);

-- ==================== 全局操作日志 ====================
CREATE TABLE operation_log (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT DEFAULT 0 COMMENT '操作人，0=未登录（注册/登录）',
  module      VARCHAR(20) NOT NULL COMMENT '模块：设备/房间/场景…',
  action      VARCHAR(50) NOT NULL COMMENT '动作：控制设备/添加房间…',
  detail      VARCHAR(500) COMMENT '请求参数摘要（JSON，密码已脱敏）',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 轮播图 ====================
CREATE TABLE banner (
  id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  title     VARCHAR(100),
  image_url VARCHAR(255) NOT NULL COMMENT '图片地址：unsplash 网图外链（完整 https URL，可直接渲染）',
  link_url  VARCHAR(255),
  position  VARCHAR(20) NOT NULL COMMENT 'home/product/shop',
  sort      INT DEFAULT 0,
  enabled   TINYINT DEFAULT 1
);

-- 高频查询索引：外键式列几乎都出现在 WHERE/JOIN 里，全表扫描虽在 demo 数据量下无感，
-- 但加上无害且是正经习惯。
ALTER TABLE device ADD INDEX idx_device_room (room_id);
ALTER TABLE device_log ADD INDEX idx_dlog_device (device_id);
ALTER TABLE scene_action ADD INDEX idx_sact_scene (scene_id);
ALTER TABLE scene_action ADD INDEX idx_sact_device (device_id);
ALTER TABLE cart_item ADD INDEX idx_cart_user (user_id);
ALTER TABLE orders ADD INDEX idx_orders_user (user_id);
ALTER TABLE order_item ADD INDEX idx_oitem_order (order_id);

-- ==================== 初始化数据 ====================
-- 演示账号：demo / 123456
INSERT INTO user (username, password, nickname) VALUES
('demo', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', '演示用户');

INSERT INTO address (user_id, receiver, phone, region, detail, is_default) VALUES
(1, '张三', '13800000000', '广东省 深圳市 南山区', '科技园路 1 号 101 室', 1);

-- 房间：3 个，按联动场景划分（客厅=灯风扇+人体感应+自动门 / 阳台=环境检测 / 厨房=烟感蜂鸣）
INSERT INTO room (user_id, name, sort) VALUES
(1, '客厅', 1), (1, '阳台', 2), (1, '厨房', 3);

-- 设备：2026-11-19 对齐硬件（Smart_Home_Demo 实训箱），每房间至少一台。
-- 可控 5 种：light 灯 / fan 风扇 / gate 舵机自动门 / beep 蜂鸣器 / smoke_sensor 烟雾传感器
-- 只读 2 种：env_sensor 环境检测（温湿度+光照，阳台）/ pir_sensor 人体感应（客厅，联动自动门）
-- 状态字段（与硬件侧华为云物模型一一对应）：
--   light  : power 开关 / brightness 亮度 / colorTemp 色温(2700·4000·6500)
--   fan    : power 开关（Motor_control）
--   gate   : power on=开门 off=关门（Servo_control）
--   beep   : power on=鸣响 off=静音（Beep_control）
--   smoke_sensor : smoke 展示值 + alarm 报警位【只读，硬件 SmokeStatus 同步】 / battery 电量【只读】
--   env_sensor   : temperature / humidity / lux【只读，硬件上报同步】
--   pir_sensor   : present on=有人 off=无人【只读，硬件 PIR_Status 同步】
--   **可控类型**都有 timerOn / timerOff —— 每日定时开 / 关（"HH:mm"，空串=不定时），
--   由服务端定时任务每分钟扫描执行并转发云端命令；带【只读】标记的字段不接受客户端下发。
-- 注意：下面 INSERT 的顺序决定自增 id（1~7），scene_action 里引用了这些 id。
--       新增设备**必须追加在末尾**，中间插入会把后面所有设备的 id 顶掉，导致场景动作指错设备。
INSERT INTO device (room_id, name, type, status) VALUES
(1, '客厅灯',       'light',        '{"power":"off","brightness":80,"colorTemp":4000,"timerOn":"","timerOff":""}'),
(1, '客厅风扇',     'fan',          '{"power":"off","timerOn":"","timerOff":""}'),
(1, '客厅自动门',   'gate',         '{"power":"off","timerOn":"","timerOff":""}'),
(3, '烟雾传感器',   'smoke_sensor', '{"power":"on","smoke":6,"alarm":0,"battery":100,"timerOn":"","timerOff":""}'),
(3, '厨房蜂鸣器',   'beep',         '{"power":"off","timerOn":"","timerOff":""}'),
(1, '人体感应',     'pir_sensor',   '{"present":"off"}'),
(2, '环境检测',     'env_sensor',   '{}');

-- 房间环境监测数据：只有阳台有传感器（真实值由华为云上报覆盖），其余房间 NULL
INSERT INTO room_environment
  (room_id, temperature, humidity, lux) VALUES
(1, NULL, NULL, NULL),
(2, NULL, NULL, NULL),
(3, NULL, NULL, NULL);

-- 系统级配置：全屋自动/手动模式（硬件 ModeStatus 同步，App 首页可切换）
CREATE TABLE IF NOT EXISTS system_config (
  config_key VARCHAR(64) NOT NULL COMMENT '配置键',
  config_value VARCHAR(255) NULL COMMENT '配置值',
  PRIMARY KEY (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统级配置（全屋模式等）';
INSERT INTO system_config (config_key, config_value) VALUES ('mode', 'AUTO');

-- 预设场景 3 个（1 个定时自动化 + 2 个手动模式），只引用上面 id 1~7 里的可控设备。
INSERT INTO scene (id, user_id, name, icon, description, trigger_type, cron_expr, enabled) VALUES
(1, 1, '回家模式', 'home', '自动门开门放行、客厅灯亮起，进门就是亮堂状态', 'MANUAL', NULL, 1),
(2, 1, '离家模式', 'away', '自动门关门、全屋灯和风扇关闭、蜂鸣器静音', 'MANUAL', NULL, 1),
(3, 1, '晚安模式', 'night', '每晚 23:00 自动关灯、蜂鸣器静音，安心入睡', 'TIMER', '23:00', 1);

INSERT INTO scene_action (scene_id, device_id, action) VALUES
-- 回家：自动门开门 + 客厅灯全亮
(1, 3, '{"power":"on"}'), (1, 1, '{"power":"on","brightness":100}'),
-- 离家：自动门关门 + 灯/风扇全关 + 蜂鸣器静音
(2, 3, '{"power":"off"}'), (2, 1, '{"power":"off"}'),
(2, 2, '{"power":"off"}'), (2, 5, '{"power":"off"}'),
-- 晚安（23:00 定时）：关灯 + 蜂鸣器静音
(3, 1, '{"power":"off"}'), (3, 5, '{"power":"off"}');

-- 产品库（product 只做介绍展示，购买走 goods）：8 个，cover 用 unsplash 网图（外链直接可加载）
INSERT INTO product (id, name, category, cover, slogan, description, specs, tags, related_goods_id) VALUES
(1, '米家智能台灯 Lite', '照明', 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=compress&cs=tinysrgb&w=600', '无频闪，护眼更安心',
 '支持无级调光与多种预设模式，可通过 App 远程控制，也能与门窗传感器联动。学习、阅读、工作三档一键切换，光线柔和不刺眼。',
 '["色温：4000K","亮度：0-100%","连接：WiFi 2.4G","额定功率：8W"]', 'WiFi,联动', 1),
(2, '米家门窗传感器 2', '安防', 'https://images.unsplash.com/photo-1558089687-f282ffcbc126?auto=compress&cs=tinysrgb&w=600', '开合有记录，异常有提醒',
 '实时监测门窗开合状态，可与灯光、警报器联动，出门在外也安心。体积小巧免布线安装，一贴即用。',
 '["电池：CR1632","续航：约 2 年","连接：蓝牙 Mesh"]', '蓝牙,联动', 2),
(3, '米家空气净化器 4', '环境', 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=compress&cs=tinysrgb&w=600', '洁净空气，看得见的安心',
 '实时显示 PM2.5 与空气质量，自动调节风量，可与空调、加湿器联动。三层滤芯层层净化，除醛除菌除异味。',
 '["CADR：400m³/h","适用面积：28-48㎡","连接：WiFi 2.4G"]', 'WiFi,联动', 3),
(4, '米家智能插座 3', '操控', 'https://images.unsplash.com/photo-1565814329452-e1efa11c5b89?auto=compress&cs=tinysrgb&w=600', '让普通电器变智能',
 '远程开关、定时任务、用电统计，把家里老电器也接入智能场景。750℃ 阻燃外壳，安全省心。',
 '["最大负载：2500W","连接：WiFi 2.4G","支持定时"]', 'WiFi,定时', 4),
(5, '米家智能摄像头 3', '安防', 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=600', '1080P 高清看家',
 '移动侦测即时推送，红外夜视全天守护，双向通话随时沟通。支持云端与本地双存储，画面回放一目了然。',
 '["分辨率：1080P","视角：130°","夜视：红外 10m","存储：云/本地"]', 'WiFi,看家', 5),
(6, '米家智能门锁 M20', '安防', 'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=compress&cs=tinysrgb&w=600', '一触即开，安全随行',
 '指纹/密码/NFC 多种开锁方式，异常撬锁即时告警。门铃一体设计，猫眼可视，谁来了看得见。',
 '["指纹识别：半导体","续航：约 12 个月","开锁：指纹/密码/NFC/临时"]', 'NFC,安防', 9),
(7, '米家空调 1.5匹', '环境', 'https://images.unsplash.com/photo-1519183071298-a2962feb14f4?auto=compress&cs=tinysrgb&w=600', '全直流变频，冷暖更快',
 '新一级能效，全直流变频技术，快速冷暖更省电。支持 App 远程控制与语音操控，智能睡眠曲线整晚安睡。',
 '["能效：新一级","匹数：1.5 匹","适用面积：16-20㎡","连接：WiFi 2.4G"]', 'WiFi,变频', 17),
(8, '小爱智能音箱 Play', '操控', 'https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=compress&cs=tinysrgb&w=600', '一句话，全屋智能',
 '一句话控制全屋设备，海量内容语音点播。红外遥控传统家电，闹钟/电台/有声书一应俱全。',
 '["连接：WiFi 2.4G / 蓝牙","红外：全屋家电遥控","内容：QQ 音乐/喜马拉雅"]', '语音,红外', 12);

INSERT INTO goods_category (id, name, sort) VALUES
(1, '智能照明', 1), (2, '安防监控', 2), (3, '环境电器', 3), (4, '厨房电器', 4),
(5, '智能操控', 5), (6, '清洁电器', 6);

-- 商城商品（可购买）：20 个。cover/images 用 unsplash 网图外链（模拟器有网即可加载，无需本地打包图片）。
-- images 为 JSON 数组轮播图；detail 用『；』分段（前端 split 渲染卖点列表）；tags 配合三字段搜索。
INSERT INTO goods (id, category_id, name, cover, images, price, origin_price, stock, sales, detail, tags) VALUES
(1, 1, '米家智能台灯 Lite',
 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1507652313519-d4e9174996dd?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?auto=compress&cs=tinysrgb&w=600"]',
 199.00, 249.00, 100, 320,
 '无频闪护眼台灯，光照面积更大更均匀；支持 App 无级调光调色温，学习阅读工作三档一键切换；可与门窗传感器等设备场景联动，入座自动亮灯；123° 大角度调节，记得住你习惯的光。（Demo 商品，仅用于演示购买流程）',
 '台灯,护眼,调光'),
(2, 2, '米家门窗传感器 2',
 'https://images.unsplash.com/photo-1558089687-f282ffcbc126?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1558089687-f282ffcbc126?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=600"]',
 59.00, 69.00, 200, 880,
 '门窗开合状态实时监测，开帘开窗一目了然；可与灯光、警报器智能联动，夜间开门自动亮灯；体积小巧免布线，背胶一贴即装；CR1632 纽扣电池续航约 2 年，低电量自动提醒。（Demo 商品）',
 '门窗,传感器,安防'),
(3, 3, '米家空气净化器 4',
 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1611145367651-6303b46e4040?auto=compress&cs=tinysrgb&w=600"]',
 799.00, 999.00, 80, 410,
 '三层滤芯层层净化，除醛除菌除异味；CADR 高达 400m³/h，适用 28-48㎡ 空间；PM2.5 数显屏实时可见，净化效果看得见；自动模式根据空气质量调节风量，省心省电；滤芯剩余寿命 App 可查。（Demo 商品）',
 '净化器,除醛,PM2.5'),
(4, 5, '米家智能插座 3',
 'https://images.unsplash.com/photo-1565814329452-e1efa11c5b89?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1565814329452-e1efa11c5b89?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?auto=compress&cs=tinysrgb&w=600"]',
 49.00, 59.00, 300, 1200,
 '让普通家电秒变智能，远程开关随手掌控；定时任务自由编排，电热水壶早晨自动烧水；用电统计帮你找出耗电大户；750℃ 阻燃外壳，最大负载 2500W 安全可靠；体积小巧不挡相邻插孔。（Demo 商品）',
 '插座,远程,定时'),
(5, 2, '米家智能摄像头 3',
 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558089687-f282ffcbc126?auto=compress&cs=tinysrgb&w=600"]',
 149.00, 179.00, 120, 450,
 '1080P 高清画质，看家更清晰；130° 大广角，房间全景尽收眼底；移动侦测即时推送，异常画面不错过；红外夜视 10 米，黑夜也能看清；双向通话，随时和孩子宠物互动；云端本地双存储，回放一目了然。（Demo 商品）',
 '摄像头,看家,夜视'),
(6, 5, '空调伴侣 Pro',
 'https://images.unsplash.com/photo-1611145367651-6303b46e4040?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1611145367651-6303b46e4040?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1519183071298-a2962feb14f4?auto=compress&cs=tinysrgb&w=600"]',
 169.00, 199.00, 180, 260,
 '让老空调秒变智能，远程开关温度随手调；语音控制说句话就搞定，小爱同学全屋联动；电量统计看清每度电花在哪；自带红外网关，可控制电视风扇等红外家电；睡眠曲线自动调温，整晚安睡。（Demo 商品）',
 '空调,红外,语音'),
(7, 5, '米家智能窗帘电机',
 'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1571508601891-ca5e7a713859?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=compress&cs=tinysrgb&w=600"]',
 599.00, 699.00, 80, 95,
 '一键开合窗帘，动口动手都行；支持定时开合，清晨阳光唤醒每一天；光照联动，烈日自动拉帘护家具；静音电机顺滑运行，开合近乎无声；停电可手动轻拉，断电不断用；轨道长度按需定制。（Demo 商品）',
 '窗帘,电机,定时'),
(8, 3, '米家智能加湿器 2',
 'https://images.unsplash.com/photo-1616464916356-3a777b2b60b1?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1616464916356-3a777b2b60b1?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1585771724684-38269d6639fd?auto=compress&cs=tinysrgb&w=600"]',
 129.00, 159.00, 200, 530,
 '上加水设计，提壶注水不弯腰；恒湿感应自动调节，4L 大水箱长效加湿；35dB 安静运行，睡觉办公都不扰；缺水自动断电保护，安心无忧；雾量可调，湿润度刚刚好。（Demo 商品）',
 '加湿器,恒湿,静音'),
(9, 2, '米家智能门锁 M20',
 'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=600"]',
 1299.00, 1499.00, 60, 80,
 '指纹/密码/NFC/临时密码多种开锁方式；半导体指纹识别，0.3 秒一触即开；异常撬锁即时告警，App 第一时间推送；门铃一体设计，访客按铃手机接收；续航约 12 个月，Type-C 应急充电；门未关提醒，粗心党的救星。（Demo 商品）',
 '门锁,指纹,NFC'),
(10, 6, '米家扫地机器人 T12',
 'https://images.unsplash.com/photo-1589894404892-7310b92ea7a2?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1589894404892-7310b92ea7a2?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=compress&cs=tinysrgb&w=600"]',
 1799.00, 2099.00, 50, 150,
 '激光导航智能规划清扫路线，全屋覆盖不漏扫；4000Pa 大吸力，毛发碎屑一扫而净；自动集尘一月一倒，解放双手；扫拖一体，湿拖除渍更干净；App 远程操控，划区清扫随心指派；电量不足自动回充，省心省力。（Demo 商品）',
 '扫地机,吸力,导航'),
(11, 3, '米家智能落地扇 2',
 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=compress&cs=tinysrgb&w=600"]',
 249.00, 299.00, 150, 380,
 '直流变频电机，100 档无级风速调节；自然风/直吹风双模式，模拟自然更舒适；上下左右四向摆头，送风范围更广；26dB 轻声运行，夜里开也不吵；与空调联动，恒温又省电；可拆卸风罩，清洗方便。（Demo 商品）',
 '风扇,变频,静音'),
(12, 5, '小爱智能音箱 Play',
 'https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1545459720-aac8509eb02c?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1589256469067-ea99122bbdc4?auto=compress&cs=tinysrgb&w=600"]',
 149.00, 199.00, 300, 760,
 '一句话控制全屋智能设备，灯光窗帘空调都听话；海量音乐有声内容语音点播；内置红外遥控，传统家电也能语音掌控；闹钟提醒日程查询，生活小助手；小巧机身多色可选，放哪都好看。（Demo 商品）',
 '音箱,语音,红外'),
(13, 1, '米家智能吸顶灯 Pro 32cm',
 'https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1513506003901-1e6a229e2d15?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=compress&cs=tinysrgb&w=600"]',
 399.00, 459.00, 90, 210,
 '32cm 大尺寸发光面，全屋照度均匀无暗区；Ra90 高显色指数，还原物体真实色彩；2700K-6500K 色温无级调节，暖光冷白随心切换；支持米家 App 与小爱语音控制；可与传感器联动，人来灯亮人走灯灭；超薄机身 4.9cm，安装不压抑。（Demo 商品）',
 '吸顶灯,色温,语音'),
(14, 5, '米家智能开关 零火双键版',
 'https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1584568694244-14fbdf83bd30?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1565814329452-e1efa11c5b89?auto=compress&cs=tinysrgb&w=600"]',
 89.00, 109.00, 260, 340,
 '普通灯秒变智能灯，不用换灯具；双键独立控制两路灯；App 远程开关，被窝里也能关灯；支持与小爱同学语音控制；可设置多键联动场景，一键全屋灯光；荧光按键，夜里也能找到开关。（Demo 商品）',
 '开关,面板,语音'),
(15, 4, '米家电饭煲 4L',
 'https://images.unsplash.com/photo-1556909212-d5b604d0c90d?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1556909212-d5b604d0c90d?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1590794056226-79ef3a8147e1?auto=compress&cs=tinysrgb&w=600"]',
 299.00, 349.00, 110, 170,
 'IH 电磁环绕加热，米粒受热更均匀；4L 容量满足 3-6 人家庭；2400+ 烹饪曲线，煮饭好口感有依据；24 小时智能预约，睡前备好早上喝粥；不粘内胆易清洗，一冲即净；App 云食谱，天天不重样。（Demo 商品）',
 '电饭煲,预约,IH'),
(16, 4, '米家破壁料理机',
 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?auto=compress&cs=tinysrgb&w=600"]',
 349.00, 429.00, 85, 95,
 '八大智能功能，豆浆米糊果蔬奶昔一键搞定；42000 转/分高速破壁，细腻无渣口感顺滑；加热搅打一体，免滤直饮；降噪风道设计，安静不扰眠；12 小时预约，起床即饮；一键自动清洗，省时省力。（Demo 商品）',
 '破壁机,豆浆,降噪'),
(17, 3, '米家空调 1.5匹 新一级能效',
 'https://images.unsplash.com/photo-1519183071298-a2962feb14f4?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1519183071298-a2962feb14f4?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1611145367651-6303b46e4040?auto=compress&cs=tinysrgb&w=600"]',
 2599.00, 2999.00, 45, 60,
 '新一级能效，全直流变频省电看得见；速冷速热，30 秒出风 60 秒暖房；智能睡眠曲线，温度随睡眠阶段自动调整；支持米家 App 远程控制与语音操控；自清洁技术，蒸发器结霜剥离污垢；适用 16-20㎡ 卧室书房。（Demo 商品）',
 '空调,变频,一级能效'),
(18, 6, '米家无线吸尘器 K10 Pro',
 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1558317374-067fb5f30001?auto=compress&cs=tinysrgb&w=600"]',
 1299.00, 1599.00, 70, 130,
 '125AW 无刷电机大吸力，地毯深处灰尘也吸净；整机 1.5kg 轻量化，单手举高不费劲；60 分钟超长续航，大户型一次搞定；5 重过滤锁住微尘，排出洁净空气；LED 尘显实时可见，吸没吸干净一目了然；多吸头配件，地面沙发键盘全场景。（Demo 商品）',
 '吸尘器,无线,大吸力'),
(19, 1, '米家LED智能灯泡 暖光双支装',
 'https://images.unsplash.com/photo-1550985616-10810253b84d?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1550985616-10810253b84d?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1616594039964-ae9021a400a0?auto=compress&cs=tinysrgb&w=600"]',
 59.00, 79.00, 400, 920,
 '双支装更划算，全屋换装好选择；2700K 暖黄光，温馨氛围拉满；无频闪无蓝光危害，久看不累眼；支持米家 App 调光，亮度随心；E27 通用螺口，拧上就能用；寿命约 25000 小时，一次装好多年。（Demo 商品）',
 '灯泡,暖光,氛围'),
(20, 1, '米家智能彩光灯带 2m',
 'https://images.unsplash.com/photo-1616594039964-ae9021a400a0?auto=compress&cs=tinysrgb&w=600',
 '["https://images.unsplash.com/photo-1616594039964-ae9021a400a0?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1507652313519-d4e9174996dd?auto=compress&cs=tinysrgb&w=600","https://images.unsplash.com/photo-1550985616-10810253b84d?auto=compress&cs=tinysrgb&w=600"]',
 129.00, 169.00, 180, 260,
 '1600 万色 RGB 光效，氛围感直接拉满；支持音乐律动，灯光随节奏跳动；可裁剪可拼接，2m 起步自由延伸；背胶粘贴免工具安装，电视墙床头一贴即亮；App 拾色器任意调色，节日主题一键换装。（Demo 商品）',
 '灯带,RGB,氛围');

INSERT INTO banner (title, image_url, link_url, position, sort, enabled) VALUES
('智慧互联 · 一屏掌控全屋', 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=compress&cs=tinysrgb&w=900', '', 'home', 1, 1),
('晚间模式 · 灯光自动调暗', 'https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=compress&cs=tinysrgb&w=900', '', 'home', 2, 1),
('舒适温湿度 · 恒稳如春', 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=compress&cs=tinysrgb&w=900', '', 'home', 3, 1),
('全品类智能产品', 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=compress&cs=tinysrgb&w=900', '', 'product', 1, 1),
('安防看家 全时守护', 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=compress&cs=tinysrgb&w=900', '', 'product', 2, 1),
('智能好物 限时直降', 'https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=compress&cs=tinysrgb&w=900', '', 'shop', 1, 1),
('新品上市 抢先体验', 'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=compress&cs=tinysrgb&w=900', '', 'shop', 2, 1);


-- =====================================================================
--  自检 SQL（导入完成后执行，用于确认数据完整）
-- =====================================================================
-- SHOW TABLES;                            -- 应看到 16 张表
-- SELECT COUNT(*) FROM user;              -- 1   （演示账号 demo / 123456）
-- SELECT COUNT(*) FROM room;              -- 4
-- SELECT COUNT(*) FROM device;            -- 19  （覆盖 17 种设备类型）
-- SELECT COUNT(*) FROM room_environment;  -- 4
-- SELECT COUNT(*) FROM scene;             -- 9
-- SELECT COUNT(*) FROM product;           -- 8
-- SELECT COUNT(*) FROM goods;             -- 20
-- SELECT COUNT(*) FROM banner;            -- 7
--
-- 中文乱码排查（HEX 应显示 utf8mb4 字节；若出现大量 3F 说明导入字符集不对）：
-- SELECT id, name, HEX(name) FROM device WHERE id = 1;
-- =====================================================================
