return {
    [2001] = {  -- 中级经验药水
        materials = {
            [1001] = 5  -- 需要5个初级经验药水
        },
        success_rate = 0.8,  -- 80%成功率
        fail_keep_material = true,  -- 失败返还材料
        output_count = 1  -- 成功产出1个
    },
    [3001] = {  -- 高级经验药水
        materials = {
            [2001] = 3  -- 需要3个中级经验药水
        },
        success_rate = 0.6,
        fail_keep_material = false,  -- 失败不返还材料
        output_count = 1
    }
} 