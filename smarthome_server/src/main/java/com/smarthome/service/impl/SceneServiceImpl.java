package com.smarthome.service.impl;

import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.dto.SceneSaveDTO;
import com.smarthome.entity.Scene;
import com.smarthome.entity.SceneAction;
import com.smarthome.mapper.SceneActionMapper;
import com.smarthome.mapper.SceneMapper;
import com.smarthome.service.DeviceService;
import com.smarthome.service.SceneService;
import com.smarthome.vo.SceneVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SceneServiceImpl implements SceneService {

    private final SceneMapper sceneMapper;
    private final SceneActionMapper sceneActionMapper;
    private final DeviceService deviceService;      // 复用设备控制逻辑，不重复写

    @Override
    public List<SceneVO> list(Long userId, String triggerType) {
        LambdaQueryWrapper<Scene> wrapper = new LambdaQueryWrapper<Scene>()
                .eq(Scene::getUserId, userId)
                .orderByAsc(Scene::getId);
        if (triggerType != null && !triggerType.isEmpty()) {
            wrapper.eq(Scene::getTriggerType, triggerType);
        }
        return sceneMapper.selectList(wrapper).stream().map(this::toVO).collect(Collectors.toList());
    }

    @Override
    public SceneVO detail(Long sceneId, Long userId) {
        Scene scene = sceneMapper.selectById(sceneId);
        if (scene == null || !scene.getUserId().equals(userId)) throw new BizException("场景不存在");
        SceneVO vo = toVO(scene);
        vo.setActions(sceneActionMapper.selectList(
                        new LambdaQueryWrapper<SceneAction>().eq(SceneAction::getSceneId, sceneId))
                .stream().map(this::toActionMap).collect(Collectors.toList()));
        return vo;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void save(Long userId, SceneSaveDTO dto) {
        if (dto.getName() == null || dto.getName().isEmpty()) throw new BizException("场景名不能为空");
        Scene scene = new Scene();
        scene.setUserId(userId);
        scene.setName(dto.getName());
        scene.setIcon(dto.getIcon());
        scene.setDescription(dto.getDescription());
        scene.setTriggerType(dto.getTriggerType() == null ? "MANUAL" : dto.getTriggerType());
        scene.setCronExpr(dto.getCronExpr());
        scene.setEnabled(dto.getEnabled() == null ? 1 : dto.getEnabled());
        sceneMapper.insert(scene);
        saveActions(scene.getId(), dto.getActions());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long userId, SceneSaveDTO dto) {
        if (dto.getId() == null) throw new BizException("缺少场景 id");
        Scene scene = sceneMapper.selectById(dto.getId());
        if (scene == null || !scene.getUserId().equals(userId)) throw new BizException("场景不存在");
        if (dto.getName() != null) scene.setName(dto.getName());
        if (dto.getIcon() != null) scene.setIcon(dto.getIcon());
        if (dto.getDescription() != null) scene.setDescription(dto.getDescription());
        if (dto.getTriggerType() != null) scene.setTriggerType(dto.getTriggerType());
        if (dto.getCronExpr() != null) scene.setCronExpr(dto.getCronExpr());
        if (dto.getEnabled() != null) scene.setEnabled(dto.getEnabled());
        sceneMapper.updateById(scene);
        // 替换动作（先删后插）
        sceneActionMapper.delete(new LambdaQueryWrapper<SceneAction>()
                .eq(SceneAction::getSceneId, scene.getId()));
        saveActions(scene.getId(), dto.getActions());
    }

    @Override
    public void remove(Long sceneId, Long userId) {
        Scene scene = sceneMapper.selectById(sceneId);
        if (scene == null || !scene.getUserId().equals(userId)) throw new BizException("场景不存在");
        sceneActionMapper.delete(new LambdaQueryWrapper<SceneAction>()
                .eq(SceneAction::getSceneId, sceneId));
        sceneMapper.deleteById(sceneId);
    }

    /**
     * 一键执行场景：把场景里的每个动作依次下发给对应设备。
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(Long sceneId, Long userId) {
        Scene scene = sceneMapper.selectById(sceneId);
        if (scene == null) throw new BizException("场景不存在");
        if (!scene.getUserId().equals(userId)) throw new BizException("无权执行该场景");

        List<SceneAction> actions = sceneActionMapper.selectList(
                new LambdaQueryWrapper<SceneAction>().eq(SceneAction::getSceneId, sceneId));
        if (actions.isEmpty()) throw new BizException("该场景还没有配置动作");

        for (SceneAction action : actions) {
            Map<String, Object> actionMap = JSONUtil.parseObj(action.getAction());
            deviceService.control(action.getDeviceId(), userId, actionMap);
        }
    }

    @Override
    public void toggle(Long sceneId, Long userId, Integer enabled) {
        Scene scene = sceneMapper.selectById(sceneId);
        if (scene == null) throw new BizException("场景不存在");
        if (!scene.getUserId().equals(userId)) throw new BizException("无权操作该场景");
        scene.setEnabled(enabled);
        sceneMapper.updateById(scene);
    }

    @Override
    public void runTimedScenes() {
        List<Scene> timedScenes = sceneMapper.selectList(new LambdaQueryWrapper<Scene>()
                .eq(Scene::getTriggerType, "TIMER")
                .eq(Scene::getEnabled, 1));

        String now = LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm"));
        for (Scene scene : timedScenes) {
            if (now.equals(scene.getCronExpr())) {      // cron_expr 存 "HH:mm"
                try {
                    run(scene.getId(), scene.getUserId());
                } catch (Exception e) {
                    System.err.println("场景执行失败：" + scene.getName() + "，" + e.getMessage());
                }
            }
        }
    }

    private void saveActions(Long sceneId, List<Map<String, Object>> actions) {
        if (actions == null) return;
        for (Map<String, Object> a : actions) {
            if (a == null || a.get("deviceId") == null) continue;
            SceneAction sa = new SceneAction();
            sa.setSceneId(sceneId);
            sa.setDeviceId(Long.valueOf(a.get("deviceId").toString()));
            sa.setAction(JSONUtil.toJsonStr(a.get("action")));
            sceneActionMapper.insert(sa);
        }
    }

    private Map<String, Object> toActionMap(SceneAction sa) {
        Map<String, Object> m = new HashMap<>();
        m.put("deviceId", sa.getDeviceId());
        m.put("action", JSONUtil.parseObj(sa.getAction()));
        return m;
    }

    private SceneVO toVO(Scene scene) {
        SceneVO vo = new SceneVO();
        vo.setId(scene.getId());
        vo.setName(scene.getName());
        vo.setIcon(scene.getIcon());
        vo.setDescription(scene.getDescription());
        vo.setTriggerType(scene.getTriggerType());
        vo.setCronExpr(scene.getCronExpr());
        vo.setEnabled(scene.getEnabled());
        return vo;
    }
}
