async function getRandomEquip(part, isReplace) {
    const request = {
        token: this.token,
        part: part || 0,       // 部位，0表示随机
        is_replace: isReplace || false // 是否替换现有装备
    };

    console.log('\nSending random equipment request:', request);

    try {
        const response = await this.sendGameRequest(
            'C2G_EQUIP_RANDOM_REQUEST',
            request,
            'command.G2CEquipRandomResponse'
        );

        console.log('Random equipment response:', JSON.stringify(response, null, 2));
        return response;
    } catch (error) {
        console.error('Failed to get random equipment:', error);
        throw error;
    }
}

module.exports = getRandomEquip;