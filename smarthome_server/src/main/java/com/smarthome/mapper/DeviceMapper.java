package com.smarthome.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.smarthome.entity.Device;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface DeviceMapper extends BaseMapper<Device> {

    /** 复杂查询才在数据层写 SQL：按用户查全部设备（联表房间） */
    @Select("""
            SELECT d.* FROM device d
            JOIN room r ON d.room_id = r.id
            WHERE r.user_id = #{userId}
            ORDER BY d.id
            """)
    List<Device> selectByUserId(Long userId);
}
