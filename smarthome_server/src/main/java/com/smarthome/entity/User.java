package com.smarthome.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 【阶段① · B 负责】用户表 user（《04_数据库设计.md》一）。
 *
 * <p>8 个字段：id / username / password / nickname / avatar / email / phone / createTime。
 *
 * <p>【驼峰映射】数据库下划线 create_time ↔ Java createTime，
 * mybatis-plus 已全局配置 map-underscore-to-camel-case，不用写 @TableField。
 *
 * <p>【为什么 @TableId(type = IdType.AUTO)】数据库是 AUTO_INCREMENT，
 * 显式声明后插入时不用自己给 id，MyBatis-Plus 会把自增主键回填到对象上。
 */
@Data
@TableName("user")
public class User {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 账号（数据库唯一索引） */
    private String username;

    /** BCrypt 密文，禁止存明文（见 UserServiceImpl.register） */
    private String password;

    private String nickname;

    /** 头像路径，本项目用后端静态资源，可空 */
    private String avatar;

    /** 邮箱（唯一索引，邮箱注册用；普通注册用户此列为 null） */
    private String email;

    /** 手机号（唯一索引，预留；可空。唯一索引允许多个 NULL） */
    private String phone;

    private LocalDateTime createTime;
}
