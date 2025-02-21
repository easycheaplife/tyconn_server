// 扩展背包处理器
async function expandBag(params) {
    // 确保已经初始化
    if (!this.protoHelper.initialized) {
        await this.protoHelper.init();
    }

    // 如果指定了bag_type，使用指定的值，否则使用默认值
    let bag_type = params.bag_type;
    if (bag_type === undefined) {
        bag_type = this.protoHelper.BagType.BAG_TYPE_MAIN;
    }

    // 构造请求
    const expandBagRequest = {
        token: this.token,
        bag_type: bag_type,
        add_size: Number(params.add_size || 1)  // 默认增加1个格子
    };

    // 打印请求信息
    console.log('\nSending expand bag request:', {
        ...expandBagRequest,
        bag_type_name: this.protoHelper.getEnumName('BagType', bag_type)
    });

    return this.sendGameRequest(
        'C2G_EXPAND_BAG_REQUEST',
        expandBagRequest,
        'command.G2CExpandBagResponse'
    );
}

module.exports = expandBag; 