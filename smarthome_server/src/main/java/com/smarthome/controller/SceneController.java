package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.dto.SceneSaveDTO;
import com.smarthome.service.SceneService;
import com.smarthome.vo.SceneVO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/scene")
@RequiredArgsConstructor
public class SceneController {

    private final SceneService sceneService;

    @GetMapping("/list")
    public Result<List<SceneVO>> list(@RequestParam(required = false) String type,
                                      HttpServletRequest request) {
        return Result.ok(sceneService.list(userId(request), type));
    }

    @GetMapping("/{id}")
    public Result<SceneVO> detail(@PathVariable Long id, HttpServletRequest request) {
        return Result.ok(sceneService.detail(id, userId(request)));
    }

    @PostMapping
    public Result<Void> save(@Valid @RequestBody SceneSaveDTO dto, HttpServletRequest request) {
        sceneService.save(userId(request), dto);
        return Result.ok();
    }

    @PutMapping
    public Result<Void> update(@Valid @RequestBody SceneSaveDTO dto, HttpServletRequest request) {
        sceneService.update(userId(request), dto);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@PathVariable Long id, HttpServletRequest request) {
        sceneService.remove(id, userId(request));
        return Result.ok();
    }

    @PostMapping("/{id}/run")
    public Result<Void> run(@PathVariable Long id, HttpServletRequest request) {
        sceneService.run(id, userId(request));
        return Result.ok();
    }

    @PutMapping("/{id}/toggle")
    public Result<Void> toggle(@PathVariable Long id,
                               @RequestBody Map<String, Object> body,
                               HttpServletRequest request) {
        Integer enabled = Integer.valueOf(body.get("enabled").toString());
        sceneService.toggle(id, userId(request), enabled);
        return Result.ok();
    }

    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
