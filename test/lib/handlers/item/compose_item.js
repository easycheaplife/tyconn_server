/**
 * 物品合成处理器
 * @param {number} targetItemId 目标物品ID
 * @param {Array<number>} materialSlots 材料格子位置数组
 * @returns {Promise<Object>}
 */
async function composeItem(targetItemId, materialSlots) {
    const request = {
        token: this.token,
        target_id: Number(targetItemId),
        material_slots: materialSlots.map(slot => Number(slot))
    };
    
    return await this.sendGameRequest(
        'C2G_COMPOSE_ITEM_REQUEST',
        request,
        'command.G2CComposeItemResponse'
    );
}

module.exports = composeItem; 