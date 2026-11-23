package com.smarthome.controller;

import com.smarthome.common.Result;
import com.smarthome.dto.EmailCodeDTO;
import com.smarthome.dto.EmailRegisterDTO;
import com.smarthome.dto.LoginDTO;
import com.smarthome.dto.RegisterDTO;
import com.smarthome.service.EmailCodeService;
import com.smarthome.service.UserService;
import com.smarthome.vo.UserInfoVO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 【阶段① · B 负责】User 模块控制层 —— 薄：接参数 -> 取当前登录人 -> 调 Service -> 包 Result。
 * 【三层红线】禁止写业务逻辑、禁止直接调 Mapper。
 *
 * <p>端点清单（《03_接口文档.md》二）：
 * <ul>
 *   <li>POST /register  注册（免登录）</li>
 *   <li>POST /login     登录，data 直接是 token 字符串（免登录）</li>
 *   <li>GET  /info      当前用户信息（含 deviceCount/orderCount）</li>
 *   <li>PUT  /profile   修改昵称/头像 —— ⚠️ 阶段① 未实现，见下方 TODO</li>
 * </ul>
 *
 * <p>【取当前登录人】{@code (Long) request.getAttribute("userId")} —— LoginInterceptor
 * 校验 token 后放进去的。每个 Controller 写一个私有方法 userId(...) 避免重复。
 */
@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    /** 只依赖业务层接口，不依赖实现类（三层架构硬要求） */
    private final UserService userService;
    private final EmailCodeService emailCodeService;

    /** 注册：入参是 RegisterDTO，返回 data 为 null（前端只看 code/msg） */
    @PostMapping("/register")
    public Result<Void> register(@Valid @RequestBody RegisterDTO dto) {
        userService.register(dto.getUsername(), dto.getNickname(), dto.getPassword());
        return Result.ok();
    }

    /** 发送邮箱验证码（免登录）：60 秒有效，存 Redis，QQ SMTP 发信 */
    @PostMapping("/email/code")
    public Result<Void> sendEmailCode(@Valid @RequestBody EmailCodeDTO dto) {
        emailCodeService.send(dto.getEmail());
        return Result.ok();
    }

    /** 邮箱注册（免登录）：验证码 + 手机号 + 密码注册，username 复用邮箱 */
    @PostMapping("/register/email")
    public Result<Void> registerByEmail(@Valid @RequestBody EmailRegisterDTO dto) {
        userService.registerByEmail(dto.getEmail(), dto.getCode(), dto.getPhone(),
                dto.getNickname(), dto.getPassword());
        return Result.ok();
    }

    /** 登录：成功时 data 直接是 JWT 字符串，前端存进 TokenStore */
    @PostMapping("/login")
    public Result<String> login(@Valid @RequestBody LoginDTO dto) {
        return Result.ok(userService.login(dto.getUsername(), dto.getPassword()));
    }

    /** 当前用户信息：必须先登录（不在 WebConfig 白名单里） */
    @GetMapping("/info")
    public Result<UserInfoVO> info(HttpServletRequest request) {
        return Result.ok(userService.info(userId(request)));
    }

    // TODO【阶段① 未做】PUT /profile 修改昵称/头像（《03_接口文档.md》二的第 4 个端点）：
    //     需要新增 ProfileDTO(nickname/avatar) + UserService.updateProfile(userId, dto)。
    //     阶段① 完成判定（注册→登录→重开仍登录→我的页显示昵称）用不到它，
    //     先按计划留空，等"我的"页要改昵称时一起做。

    /**
     * 从 request 里取 LoginInterceptor 放进去的当前登录人 id。
     * 抽成私有方法，避免每个端点都写一遍强转。
     */
    private Long userId(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}
