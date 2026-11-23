package com.smarthome.service;

import com.smarthome.dto.ProfileDTO;
import com.smarthome.vo.UserInfoVO;

/**
 * 【阶段① · B 负责】用户模块业务接口（《03_接口文档.md》二、手册 3.4）。
 *
 * <p>三个方法：
 * <ul>
 *   <li>{@code register}：注册（查重 + BCrypt 加密）</li>
 *   <li>{@code login}：登录，返回 JWT token</li>
 *   <li>{@code info}：当前用户信息，含设备数/订单数统计</li>
 * </ul>
 *
 * <p>【为什么要单独定义接口 + impl】Controller 只依赖这个接口，不依赖实现类。
 * 好处是换实现（比如加缓存）不用动 Controller，也方便单元测试打桩 ——
 * 这是三层架构的硬要求（总方案 3.1）。
 */
public interface UserService {

    /**
     * 注册新用户。
     *
     * @param username 账号，不可重复
     * @param nickname 昵称，可为空（为空时用 username 代替）
     * @param password 明文密码，内部会用 BCrypt 加密后再入库
     */
    void register(String username, String nickname, String password);

    /**
     * 邮箱注册：校验 Redis 验证码（60 秒有效）→ 查邮箱/手机号重复 → 入库。
     * username 直接存邮箱地址，普通登录接口不用改就能登录。
     *
     * @param email    邮箱（唯一，重复注册抛异常）
     * @param code     用户填写的 6 位验证码
     * @param phone    手机号（2026-09-29 新增，唯一，11 位 1 开头）
     * @param nickname 昵称可空，为空用邮箱前缀兜底
     * @param password 明文密码
     */
    void registerByEmail(String email, String code, String phone, String nickname, String password);

    /**
     * 登录（2026-09-29 改造：账号支持 用户名 / 邮箱 / 手机号 任一标识）。
     *
     * @return JWT token（前端存进 TokenStore，后续请求放进请求头 token）
     */
    String login(String account, String password);

    /**
     * 查询当前用户信息 + 统计。
     *
     * @param userId 当前登录人（由 LoginInterceptor 放进 request 后取到）
     */
    UserInfoVO info(Long userId);

    /** 修改个人资料（昵称/头像） */
    void updateProfile(Long userId, ProfileDTO dto);
}
