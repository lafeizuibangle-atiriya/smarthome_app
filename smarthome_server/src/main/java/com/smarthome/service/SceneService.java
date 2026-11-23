package com.smarthome.service;

import com.smarthome.dto.SceneSaveDTO;
import com.smarthome.vo.SceneVO;

import java.util.List;

/** 智能场景模块（手册第五章）。 */
public interface SceneService {
    List<SceneVO> list(Long userId, String triggerType);
    SceneVO detail(Long sceneId, Long userId);
    void save(Long userId, SceneSaveDTO dto);
    void update(Long userId, SceneSaveDTO dto);
    void remove(Long sceneId, Long userId);
    void run(Long sceneId, Long userId);
    void toggle(Long sceneId, Long userId, Integer enabled);
    /** 定时任务调用：扫描到点的自动化并执行 */
    void runTimedScenes();
}
