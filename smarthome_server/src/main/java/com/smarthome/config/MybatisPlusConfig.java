package com.smarthome.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * MyBatis-Plus 分页插件配置（2026-11-23 后端增强）。
 *
 * <p>【为什么必须配这个 Bean】MyBatis-Plus 的 Page 查询默认不做物理分页——
 * 不注册 {@link PaginationInnerInterceptor} 的话，selectPage 会查出全表再"假分页"，
 * 数据量大时直接拖垮接口。注册后 MP 会在 SQL 上拼 LIMIT，并把总数一并带回。
 *
 * <p>使用方式（Service 层）：
 * <pre>
 * Page&lt;DeviceLog&gt; page = deviceLogMapper.selectPage(
 *         new Page&lt;&gt;(pageNum, pageSize),            // 第几页、每页几条（页码从 1 开始）
 *         new LambdaQueryWrapper&lt;DeviceLog&gt;().eq(...));
 * page.getRecords()  // 当前页数据
 * page.getTotal()    // 总条数
 * </pre>
 */
@Configuration
public class MybatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        // 指定 MySQL 方言，生成的 LIMIT 语句才正确
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
