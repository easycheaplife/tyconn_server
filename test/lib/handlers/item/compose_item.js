/**
 * 物品合成处理器
 * @param {number} targetItemId 目标物品ID
 * @returns {Promise<Object>}
 */
async function composeItem(targetItemId) {
    const request = {
        token: this.token,
        target_id: Number(targetItemId),
    };
    
    return await this.sendGameRequest(
        'C2G_COMPOSE_ITEM_REQUEST',
        request,
        'command.G2CComposeItemResponse'
    );
}

module.exports = composeItem; 