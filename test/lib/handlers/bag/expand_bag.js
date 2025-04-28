/**
 * 扩展背包处理器
 * @param {Object} params 
 * @param {number} params.bag_type 背包类型
 * @param {number} params.add_size 扩展大小
 * @returns {Promise<Object>}
 */
async function expandBag(bag_type, add_size) {
    const request = {
        token: this.token,
        bag_type: bag_type,
        add_size: add_size
    };  
    return await this.sendGameRequest(
        'C2G_EXPAND_BAG_REQUEST',
        request,
        'command.G2CExpandBagResponse'
    );
}

module.exports = expandBag; 