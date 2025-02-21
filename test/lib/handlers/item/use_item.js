// 使用物品处理器
async function useItem(itemId, count) {
    const request = {
        token: this.token,
        item_id: itemId,
        count: count || 1
    };

    return this.sendGameRequest(
        'C2G_USE_ITEM_REQUEST',
        request,
        'command.G2CUseItemResponse'
    );
}

module.exports = useItem; 