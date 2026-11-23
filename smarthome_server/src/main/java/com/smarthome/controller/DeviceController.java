package com.smarthome.controller;

import com.smarthome.common.PageVO;
import com.smarthome.common.Result;
import com.smarthome.dto.DeviceAddDTO;
import com.smarthome.dto.RoomEnvDTO;
import com.smarthome.entity.DeviceLog;
import com.smarthome.service.DeviceService;
import com.smarthome.vo.DeviceVO;
import com.smarthome.vo.HomeOverviewVO;
import com.smarthome.vo.RoomEnvironmentVO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;

    /** 首页总览：房间 + 设备 + 每个房间的环境数据（等长同序）+ 全屋告警数 + 全屋模式 */
    @GetMapping("/home/overview")
    public Result<HomeOverviewVO> overview(HttpServletRequest request) {
        return Result.ok(deviceService.overview(userId(request)));
    }

    /**
     * 全屋自动/手动模式切换（2026-11-20 新增）。
     * body: {"mode":"AUTO"} 或 {"mode":"MANUAL"}；返回切换后的模式。
     * 硬件执行成功后 ModeStatus 上报，会自动把库里的值对齐为真实状态。
     */
    @PostMapping("/home/mode")
    public Result<String> setMode(@RequestBody Map<String, Object> body,
                                  HttpServletRequest request) {
        Object mode = body == null ? null : body.get("mode");
        return Result.ok(deviceService.setMode(mode == null ? "" : String.valueOf(mode),
                userId(request)));
    }

    @GetMapping("/device/list")
    public Result<List<DeviceVO>> list(@RequestParam Long roomId, HttpServletRequest request) {
        return Result.ok(deviceService.listByRoom(roomId, userId(request)));
    }

    @GetMapping("/device/{id}")
    public Result<DeviceVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(deviceService.detail(id, userId(request)));
    }

    /** 控制设备：body 为动作 JSON，如 {"power":"on"}（灯/风扇/自动门/蜂鸣器发 power） */
    @PostMapping("/device/{id}/control")
    public Result<DeviceVO> control(@PathVariable Long id,
                                    @RequestBody Map<String, Object> action,
                                    HttpServletRequest request) {
        return Result.ok(deviceService.control(id, userId(request), action));
    }

    @PostMapping("/device")
    public Result<Void> add(@Valid @RequestBody DeviceAddDTO dto, HttpServletRequest request) {
        deviceService.add(dto, userId(request));
        return Result.ok();
    }

    /** 重命名设备：body {"id":1,"name":"客厅吊灯"} */
    @PutMapping("/device")
    public Result<Void> rename(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        Object id = body.get("id");
        Object name = body.get("name");
        if (id == null) return Result.error(400, "设备 id 不能为空");
        deviceService.rename(Long.valueOf(id.toString()), userId(request),
                name == null ? null : name.toString());
        return Result.ok();
    }

    @DeleteMapping("/device/{id}")
    public Result<Void> remove(@PathVariable Long id, HttpServletRequest request) {
        deviceService.remove(id, userId(request));
        return Result.ok();
    }

    /** 设备操作记录 */
    @GetMapping("/device/{id}/logs")
    public Result<List<DeviceLog>> logs(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(deviceService.logs(id, userId(request)));
    }

    /** 设备操作日志分页版（2026-11-23 后端增强）：GET /api/device/{id}/logs/page?pageNum=1&pageSize=10 */
    @GetMapping("/device/{id}/logs/page")
    public Result<PageVO<DeviceLog>> logsPage(@PathVariable Long id,
                                              @RequestParam(required = false, defaultValue = "1") Integer pageNum,
                                              @RequestParam(required = false, defaultValue = "10") Integer pageSize,
                                              HttpServletRequest request) {
        return Result.ok(deviceService.logsPage(id, userId(request), pageNum, pageSize));
    }

    /** 设备类型字典（5 种，与硬件侧设备对应，字典在 common/DeviceTypes.java） */
    @GetMapping("/device/types")
    public Result<List<Map<String, Object>>> types() {
        return Result.ok(deviceService.types());
    }

    // ---------- 环境监测（2026-09 新增） ----------

    /** 查单个房间的环境监测数据 */
    @GetMapping("/room/{roomId}/environment")
    public Result<RoomEnvironmentVO> environment(@PathVariable Long roomId,
                                                 HttpServletRequest request) {
        return Result.ok(deviceService.environment(roomId, userId(request)));
    }

    /**
     * 手动刷新环境数据。required = false：允许空 body（只采样）。
     * body 传了字段就直接覆盖成该值 —— 演示时可一键造出"烟雾报警 / 燃气泄漏"效果。
     */
    @PostMapping("/room/{roomId}/environment/refresh")
    public Result<RoomEnvironmentVO> refreshEnvironment(@PathVariable Long roomId,
                                                        @RequestBody(required = false) RoomEnvDTO dto,
                                                        HttpServletRequest request) {
        return Result.ok(deviceService.refreshEnvironment(roomId, userId(request), dto));
    }

    /** 环境指标字典 */
    @GetMapping("/environment/metrics")
    public Result<List<Map<String, String>>> envMetrics() {
        return Result.ok(deviceService.envMetrics());
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
