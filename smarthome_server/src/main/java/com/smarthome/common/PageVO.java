package com.smarthome.common;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.List;

/**
 * 通用分页返回（2026-11-23 后端增强）。
 *
 * <p>为什么不直接返回 MyBatis-Plus 的 Page 对象：Page 里带 orders/searchCount 等
 * 框架字段，序列化后前端拿到一堆用不到的键；统一收口成 4 个字段，
 * 前端分页组件只需 list / total 两个。
 *
 * @param <T> 行数据类型
 */
@Data
@AllArgsConstructor
public class PageVO<T> {

    /** 当前页数据 */
    private List<T> list;

    /** 总条数 */
    private Long total;

    /** 页码（从 1 开始） */
    private Long pageNum;

    /** 每页条数 */
    private Long pageSize;

    /** 从 MyBatis-Plus 的 Page 结果快速构造 */
    public static <T> PageVO<T> of(List<T> records, long total, long pageNum, long pageSize) {
        return new PageVO<>(records, total, pageNum, pageSize);
    }
}
