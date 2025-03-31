// 处理格子事件处理器
async function handleCellEvent(eventId) {
    const request = {
        token: this.token,
        event_id: eventId
    };

    return this.sendGameRequest(
        this.protoHelper.MessageID.C2G_HANDLE_CELL_EVENT_REQUEST,
        request,
        'command.G2CHandleCellEventResponse'
    );
}

module.exports = handleCellEvent; 