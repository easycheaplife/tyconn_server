// 装备物品处理器
async function equipItem(bagType, slotIndex, equipSlot) {
    const request = {
        token: this.token,
        bag_type: bagType,     // 背包类型
        slot_index: slotIndex,  // 修改这里，使用slot_index代替bag_slot
        equip_slot: equipSlot  // 装备槽位
    };

    console.log(`\nAttempting to equip to slot ${equipSlot}...`);
    console.log('Sending equip item request:', request);

    const response = await this.sendGameRequest(
        'C2G_EQUIP_ITEM_REQUEST',
        request,
        'command.G2CEquipItemResponse'
    );

    // 打印响应
    console.log('Equip item response:', JSON.stringify(response, null, 2));

    return response;
}

module.exports = equipItem; 