package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.dto.RoomDTO;
import com.smarthome.entity.Room;
import com.smarthome.service.DeviceService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 房间接口。房间与设备/环境同属一个业务域，增删改查逻辑在 DeviceService。
 */
@RestController
@RequestMapping("/api/room")
@RequiredArgsConstructor
public class RoomController {

    private final DeviceService deviceService;

    @GetMapping("/list")
    public Result<List<Room>> list(HttpServletRequest request) {
        return Result.ok(deviceService.roomList(userId(request)));
    }

    /** 新增房间：body 形如 {"name":"书房"}；2026-11-23 改用 @Valid RoomDTO 走统一参数校验（接口测试发现原来 @Size(max=10) 未生效） */
    @PostMapping
    public Result<Void> add(@Valid @RequestBody RoomDTO dto, HttpServletRequest request) {
        deviceService.addRoom(dto.getName(), userId(request));
        return Result.ok();
    }

    /** 重命名房间：body 形如 {"id":3,"name":"大厨房"} */
    @PutMapping
    public Result<Void> rename(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        Object id = body.get("id");
        Object name = body.get("name");
        if (id == null || name == null) {
            return Result.error(400, "房间 id 与名称都不能为空");
        }
        deviceService.renameRoom(Long.valueOf(id.toString()), userId(request), name.toString());
        return Result.ok();
    }

    /** 删除房间（房间下还有设备时拒绝） */
    @DeleteMapping("/{roomId}")
    public Result<Void> remove(@PathVariable Long roomId, HttpServletRequest request) {
        deviceService.removeRoom(roomId, userId(request));
        return Result.ok();
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
