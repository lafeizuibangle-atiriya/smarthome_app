package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 场景动作表 scene_action。action 是 JSON 字符串，如 {"power":"on","brightness":20}。
 */
@Data
@TableName("scene_action")
public class SceneAction {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long sceneId;
    private Long deviceId;
    private String action; // JSON 字符串
}
