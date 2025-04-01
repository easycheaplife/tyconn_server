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

    // 转换事件数据格式
    if (response && response.event_ids) {
        response.event_ids = response.event_ids.map(event => ({
            event_id: event.event_id,
            cell_id: event.cell_id
        }));
    }

    return response;
}

module.exports = rollDice; 