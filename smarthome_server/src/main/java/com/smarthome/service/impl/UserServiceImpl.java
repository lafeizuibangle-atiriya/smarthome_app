package com.smarthome.service.impl;

import cn.hutool.crypto.digest.BCrypt;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.smarthome.common.BizException;
import com.smarthome.common.JwtUtil;
import com.smarthome.dto.ProfileDTO;
import com.smarthome.entity.Device;
import com.smarthome.entity.Orders;
import com.smarthome.entity.User;
import com.smarthome.mapper.DeviceMapper;
import com.smarthome.mapper.OrdersMapper;
import com.smarthome.mapper.UserMapper;
import com.smarthome.service.EmailCodeService;
import com.smarthome.service.UserService;
import com.smarthome.vo.UserInfoVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 【阶段① · B 负责】用户模块业务实现（手册 3.4）。
 *
 * <p>三个方法：
 * <ul>
 *   <li>{@code register}：先 selectCount 查重名 → BCrypt.hashpw 加密入库（永不存明文）</li>
 *   <li>{@code login}：查不到或 BCrypt.checkpw 失败都抛同一个提示 —— 不暴露账号是否注册；
 *       成功 return JwtUtil.createToken(user.getId())</li>
 *   <li>{@code info}：统计类数据在业务层算好，前端直接用</li>
 * </ul>
 *
 * <p>【三层红线】业务规则 / 权限校验 / 事务 / Entity↔VO 转换都在这里；
 * 禁止写 SQL（那是 Mapper 的事）、禁止碰 HttpServletRequest（那是 Controller 的事）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    /** @RequiredArgsConstructor 会为 final 字段生成构造器，Spring 自动注入（不用写 @Autowired） */
    private final UserMapper userMapper;
    private final DeviceMapper deviceMapper;
    private final OrdersMapper ordersMapper;
    private final EmailCodeService emailCodeService;

    /** 邮箱格式（后端兜底校验，前端也校验一次） */
    private static final String EMAIL_REGEX =
            "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";

    /** 手机号格式（2026-09-29 邮箱注册新增手机号字段） */
    private static final String PHONE_REGEX = "^1[3-9]\\d{9}$";

    @Override
    public void register(String username, String nickname, String password) {
        // 1. 查重：数据库 username 上有唯一索引，但先查一次能给用户更友好的提示
        Long exists = userMapper.selectCount(
                new LambdaQueryWrapper<User>().eq(User::getUsername, username));
        if (exists > 0) {
            throw new BizException("该账号已被注册");
        }

        // 2. 组装入库：密码必须 BCrypt 加密，数据库里绝不能出现明文
        User user = new User();
        user.setUsername(username);
        user.setPassword(BCrypt.hashpw(password));      // 每次加盐，同一密码的密文也不同
        // 昵称可空，为空时用账号兜底 —— 避免前端漏填导致"我的"页显示空白
        user.setNickname((nickname == null || nickname.isEmpty()) ? username : nickname);
        userMapper.insert(user);

        log.info("[用户] 注册成功：id={} username={}", user.getId(), username);
    }

    @Override
    public void registerByEmail(String email, String code, String phone, String nickname, String password) {
        // 0. 后端兜底校验（前端拦了也要防绕过）
        if (email == null || !email.matches(EMAIL_REGEX)) {
            throw new BizException("邮箱格式不正确");
        }
        if (password == null || password.length() < 6) {
            throw new BizException("密码至少 6 位");
        }
        if (phone == null || !phone.matches(PHONE_REGEX)) {
            throw new BizException("手机号格式不正确（11 位，1 开头）");
        }

        // 1. 先校验验证码（Redis 60 秒有效；通过后立即作废，一个码只能注册一次）
        emailCodeService.verify(email, code);

        // 2. 查邮箱重复：邮箱存两处（username 列 + email 列），两边都要唯一
        //    数据库上有唯一索引兜底（uk_user_email），这里先查给友好提示
        Long exists = userMapper.selectCount(
                new LambdaQueryWrapper<User>().eq(User::getEmail, email));
        if (exists > 0) {
            throw new BizException("该邮箱已被注册");
        }
        // 手机号查重（user 表 v5 起有 phone 唯一索引，先查给友好提示）
        Long phoneExists = userMapper.selectCount(
                new LambdaQueryWrapper<User>().eq(User::getPhone, phone));
        if (phoneExists > 0) {
            throw new BizException("该手机号已被注册");
        }

        // 3. 入库：username 复用邮箱 → 普通登录接口（username+password）零改动可登录
        User user = new User();
        user.setUsername(email);
        user.setEmail(email);
        user.setPhone(phone);
        user.setPassword(BCrypt.hashpw(password));
        user.setNickname((nickname == null || nickname.isEmpty())
                ? email.substring(0, email.indexOf('@')) : nickname);
        try {
            userMapper.insert(user);
        } catch (org.springframework.dao.DuplicateKeyException e) {
            // 并发注册同邮箱/同手机号时唯一索引兜底
            throw new BizException("该邮箱或手机号已被注册");
        }

        log.info("[用户] 邮箱注册成功：id={} email={} phone={}", user.getId(), email, phone);
    }

    @Override
    public String login(String account, String password) {
        // 2026-09-29 改造：支持 用户名 / 邮箱 / 手机号 任一标识 + 密码。
        // 邮箱注册用户 username 就是邮箱，所以第一查就能命中大部分场景；
        // 手机号/别名用户落在第二、三查。三处都没查到 → 与密码错误同一提示。
        User user = userMapper.selectOne(
                new LambdaQueryWrapper<User>().eq(User::getUsername, account));
        if (user == null) {
            user = userMapper.selectOne(
                    new LambdaQueryWrapper<User>().eq(User::getEmail, account));
        }
        if (user == null) {
            user = userMapper.selectOne(
                    new LambdaQueryWrapper<User>().eq(User::getPhone, account));
        }

        // 账号不存在与密码错误返回同一提示，避免暴露"这个账号有没有注册过"
        if (user == null || !BCrypt.checkpw(password, user.getPassword())) {
            log.info("[用户] 登录失败：account={}", account);
            throw new BizException("账号或密码错误");
        }

        log.info("[用户] 登录成功：id={} username={}", user.getId(), user.getUsername());
        return JwtUtil.createToken(user.getId());
    }

    @Override
    public UserInfoVO info(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException("用户不存在");
        }

        UserInfoVO vo = new UserInfoVO();
        vo.setId(user.getId());
        vo.setUsername(user.getUsername());
        vo.setNickname(user.getNickname());
        vo.setAvatar(user.getAvatar());

        // 统计字段：设备数按 userId 联房间查设备；订单数、待付款、已付款按 userId 统计 orders
        int deviceCount = deviceMapper.selectByUserId(userId).size();
        int orderCount = Math.toIntExact(ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>().eq(Orders::getUserId, userId)));
        int orderPending = Math.toIntExact(ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>().eq(Orders::getUserId, userId).eq(Orders::getStatus, 0)));
        int orderPaid = Math.toIntExact(ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>().eq(Orders::getUserId, userId).eq(Orders::getStatus, 1)));
        vo.setDeviceCount(deviceCount);
        vo.setOrderCount(orderCount);
        vo.setOrderPending(orderPending);
        vo.setOrderPaid(orderPaid);

        log.info("[用户] 查询用户信息：id={} nickname={} 设备{} 订单{} 待付{} 已付{}",
                userId, user.getNickname(), deviceCount, orderCount, orderPending, orderPaid);
        return vo;
    }

    @Override
    public void updateProfile(Long userId, ProfileDTO dto) {
        User user = userMapper.selectById(userId);
        if (user == null) throw new BizException("用户不存在");
        if (dto.getNickname() != null && !dto.getNickname().isEmpty()) {
            user.setNickname(dto.getNickname());
        }
        if (dto.getAvatar() != null) {
            user.setAvatar(dto.getAvatar());
        }
        userMapper.updateById(user);
        log.info("[用户] 修改资料：id={}", userId);
    }
}
