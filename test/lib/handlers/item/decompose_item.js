/**
 * 物品分解处理器
 * @param {number} targetId 目标物品ID
 * @returns {Promise<Object>}
 */
async function decomposeItem(targetId) {
    const request = {
        token: this.token,
        target_id: targetId
    };
    
    return await this.sendGameRequest(
        'C2G_DECOMPOSE_ITEM_REQUEST',
        request,
        'command.G2CDecomposeItemResponse'
    );
}

module.exports = decomposeItem; 