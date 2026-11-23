package com.smarthome.vo;

import cn.hutool.json.JSONObject;
import lombok.Data;

/** 设备出参。status 直接给对象，App 端不用自己 parse JSON 字符串。 */
@Data
public class DeviceVO {
    private Long id;
    private Long roomId;
    private String name;
    private String type;
    private Integer online;
    private JSONObject status;    // 直接给对象，App 端不用自己 parse JSON 字符串
}
