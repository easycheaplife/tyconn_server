/**
 * 背包排序处理器
 * @param {number} bag_type 背包类型
 * @param {number} sort_rule 排序规则
 * @returns {Promise<Object>}
 */
async function sortBag(bag_type, sort_rule) {
    const request = {
        token: this.token,
        bag_type: Number(bag_type), // 确保是数字
        sort_rule: Number(sort_rule)
    };
    return await this.sendGameRequest(
        'C2G_SORT_BAG_REQUEST',
        request,
        'command.G2CSortBagResponse'
    );
}

module.exports = sortBag; 