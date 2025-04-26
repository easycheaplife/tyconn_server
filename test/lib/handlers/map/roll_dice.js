// 掷骰子处理器
async function rollDice() {
    const request = {
        token: this.token
    };

    const response = await this.sendGameRequest(
        this.protoHelper.MessageID.C2G_ROLL_DICE_REQUEST,
        request,
        'command.G2CRollDiceResponse'
    );

    // 调试原始响应
    console.log("RollDice原始响应:", JSON.stringify(response, null, 2));

    // 检查event_ids的结构
    if (response && response.event_ids) {
        console.log("Event原始数据:");
        response.event_ids.forEach((event, index) => {
            console.log(`事件 ${index}:`, event);
            console.log(`is_random_event类型: ${typeof event.is_random_event}, 值: ${event.is_random_event}`);
        });

        // 转换事件数据格式
        response.event_ids = response.event_ids.map(event => ({
            event_id: event.event_id,
            cell_id: event.cell_id,
            is_random_event: event.is_random_event || false
        }));
    }

    // 处理random_events字段
    if (response && response.random_events) {
        console.log("随机事件原始数据:");
        response.random_events.forEach((event, index) => {
            console.log(`随机事件 ${index}:`, event);
            console.log(`is_random_event类型: ${typeof event.is_random_event}, 值: ${event.is_random_event}`);
        });

        // 转换随机事件数据格式
        response.random_events = response.random_events.map(event => ({
            event_id: event.event_id,
            cell_id: event.cell_id,
            is_random_event: event.is_random_event !== undefined ? event.is_random_event : true // 随机事件默认为true
        }));
    } else {
        // 如果没有随机事件，设置为空数组
        response.random_events = [];
    }

    return response;
}

module.exports = rollDice; 