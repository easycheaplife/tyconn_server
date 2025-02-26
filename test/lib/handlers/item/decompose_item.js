/**
 * 物品分解处理器
 * @param {Array<number>} itemSlots 要分解的物品格子位置数组
 * @returns {Promise<Object>}
 */
async function decomposeItem(itemSlots) {
    const request = {
        token: this.token,
        item_slots: itemSlots.map(slot => Number(slot))
    };
    
    return await this.sendGameRequest(
        'C2G_DECOMPOSE_ITEM_REQUEST',
        request,
        'command.G2CDecomposeItemResponse'
    );
}

module.exports = decomposeItem; 