return {
    [2001] = {  -- 中级经验药水
        outputs = {
            [1001] = {  -- 初级经验药水
                count = 3,  -- 基础产出3个
                extra_rate = 0.3,  -- 30%概率额外产出
                extra_count = 1  -- 额外产出1个
            }
        }
    },
    [3001] = {  -- 高级经验药水
        outputs = {
            [2001] = {  -- 中级经验药水
                count = 2,
                extra_rate = 0.2,
                extra_count = 1
            },
            [1001] = {  -- 初级经验药水
                count = 1,
                extra_rate = 0.5,
                extra_count = 2
            }
        }
    }
} 