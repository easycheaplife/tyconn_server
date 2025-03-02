// 升级装备系统等级处理器
async function upgradeEquipLevel() {
    const request = {
        token: this.token
    };

    // 打印请求信息
    console.log('\nSending equipment level upgrade request:', request);

    const response = await this.sendGameRequest(
        'C2G_EQUIP_LEVEL_UPGRADE_REQUEST',
        request,
        'command.G2CUpgradeEquipLevelResponse'
    );

    // 打印响应
    console.log('Equipment level upgrade response:', JSON.stringify(response, null, 2));

    return response;
}

module.exports = upgradeEquipLevel; 