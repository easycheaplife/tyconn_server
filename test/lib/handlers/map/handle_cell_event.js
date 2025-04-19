// 处理格子事件处理器
async function handleCellEvent(eventId, cellId, isRandomEvent = false) {
    const request = {
        token: this.token,
        event_info: {
            event_id: eventId,
            cell_id: cellId,
            is_random_event: isRandomEvent
        }
    };

    return this.sendGameRequest(
        this.protoHelper.MessageID.C2G_HANDLE_CELL_EVENT_REQUEST,
        request,
        'command.G2CHandleCellEventResponse'
    );
}

module.exports = handleCellEvent; 