// 获取背包信息处理器
async function getBagInfo() {
    const request = {
        token: this.token
    };

    // 打印请求信息
    console.log('\nSending bag info request:', request);

    const response = await this.sendGameRequest(
        'C2G_BAG_INFO_REQUEST',
        request,
        'command.G2CBagInfoResponse'
    );

    // 打印原始响应
    console.log('Raw response:', JSON.stringify(response, null, 2));

    // 处理响应数据
    if (response && response.bags) {
        for (const bag of response.bags) {
            if (bag.items) {
                const processedItems = [];
                for (const item of bag.items) {
                    // 根据协议定义的字段顺序重新构造物品数据
                    const processedItem = {
                        item_id: Number(item.item_id || item.count || 0),  // 第一个数字是 item_id
                        count: Number(item.count || item.slot || 0),       // 第二个数字是 count
                        slot: Number(item.slot || 0)                       // 第三个数字是 slot
                    };
                    processedItems.push(processedItem);
                }
                bag.items = processedItems;
            }
        }
    }

    // 打印处理后的响应
    console.log('Processed response:', JSON.stringify(response, null, 2));

    return response;
}

module.exports = getBagInfo; 