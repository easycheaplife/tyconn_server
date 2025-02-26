/**
 * 移动物品处理器
 * @param {number} src_bag_type 源背包类型
 * @param {number} src_slot 源格子位置
 * @param {number} dst_bag_type 目标背包类型
 * @param {number} dst_slot 目标格子位置
 * @returns {Promise<Object>}
 */
async function moveItem(src_bag_type, src_slot, dst_bag_type, dst_slot) {
    const request = {
        token: this.token,
        src_bag_type: Number(src_bag_type),
        src_slot: Number(src_slot),
        dst_bag_type: Number(dst_bag_type),
        dst_slot: Number(dst_slot)
    };
    
    return await this.sendGameRequest(
        'C2G_MOVE_ITEM_REQUEST',
        request,
        'command.G2CMoveItemResponse'
    );
}

module.exports = moveItem; 