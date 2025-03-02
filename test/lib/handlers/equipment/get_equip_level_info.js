// 获取装备等级信息处理器
async function getEquipLevelInfo() {
    const request = {
        token: this.token
    };

    console.log('\nSending equipment level info request:', request);

    try {
        const response = await this.sendGameRequest(
            'C2G_EQUIP_LEVEL_INFO_REQUEST',
            request,
            'command.G2CEquipLevelInfoResponse'
        );

        console.log('Equipment level info response:', JSON.stringify(response, null, 2));
        return response;
    } catch (error) {
        console.error('Failed to get equipment level info:', error);
        throw error;
    }
}

module.exports = getEquipLevelInfo; 