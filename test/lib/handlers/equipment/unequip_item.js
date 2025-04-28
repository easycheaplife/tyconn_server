// 卸下装备处理器
async function unequipItem(equipSlot) {
    const request = {
        token: this.token,
        equip_slot: equipSlot  // 装备槽位
    };

    // 打印请求信息
    console.log('\nSending unequip item request:', request);

    const response = await this.sendGameRequest(
        'C2G_UNEQUIP_ITEM_REQUEST',
        request,
        'command.G2CUnequipItemResponse'
    );

    // 打印响应
    console.log('Unequip item response:', JSON.stringify(response, null, 2));

    return response;
}

module.exports = unequipItem; 