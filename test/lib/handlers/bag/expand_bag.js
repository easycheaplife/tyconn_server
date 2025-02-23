/**
 * 扩展背包处理器
 * @param {number} bagType - 背包类型
 * @param {number} addSize - 扩展大小
 * @returns {Promise<object>} 响应结果
 */
async function expandBag(bagType, addSize) {
    const response = await this.sendGameRequest(
        'C2G_EXPAND_BAG_REQUEST',
        {
            token: this.token,
            bag_type: bagType,
            add_size: addSize
        },
        'bag.G2CExpandBagResponse'
    );
    return response;
}

module.exports = expandBag; 