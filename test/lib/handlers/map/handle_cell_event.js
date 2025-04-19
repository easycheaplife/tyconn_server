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

    const response = await this.sendGameRequest(
        this.protoHelper.MessageID.C2G_HANDLE_CELL_EVENT_REQUEST,
        request,
        'command.G2CHandleCellEventResponse'
    );
    
    // 打印调试信息
    console.log("HandleCellEvent原始响应:", JSON.stringify(response, null, 2));

    return response;
}

module.exports = handleCellEvent; 