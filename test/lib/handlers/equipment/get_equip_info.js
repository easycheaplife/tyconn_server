// 获取装备信息处理器
async function getEquipInfo() {
    // 检查并调试token值
    console.log("Current token in getEquipInfo:", this.token);
    
    // 构建请求时显式检查token
    const request = {
        token: this.token
    };

    // 打印请求信息
    console.log('\nSending equipment info request:', request);

    try {
        const response = await this.sendGameRequest(
            'C2G_EQUIP_INFO_REQUEST',
            request,
            'command.G2CEquipInfoResponse'
        );

        // 打印原始响应
        console.log('Raw equipment response:', JSON.stringify(response, null, 2));

        // 如果响应为空对象，使用默认值
        if (!response || Object.keys(response).length === 0) {
            response = {
                equipped_items: [],
                combat_power: 0
            };
        }

        // 处理响应数据，规范化装备物品信息
        if (response.equipped_items) {
            for (const item of response.equipped_items) {
                if (typeof item.props === 'string') {
                    try {
                        item.props = JSON.parse(item.props);
                    } catch (e) {
                        item.props = {};
                    }
                } else if (!item.props) {
                    item.props = {};
                }
            }
        }

        // 添加装备等级信息 (如果存在)
        if (response && response.level) {
            console.log('Equipment system level:', response.level);
        }

        // 打印处理后的响应
        console.log('Processed equipment response:', JSON.stringify(response, null, 2));

        return response;
    } catch (error) {
        console.error('Failed to get equipment info:', error);
        throw error;
    }
}

module.exports = getEquipInfo; 