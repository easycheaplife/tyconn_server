// 心跳处理器
async function sendHeartbeat(token) {
    const request = {
        token: token || this.token,
        timestamp: Date.now()
    };

    return this.sendGameRequest(
        'C2G_HEARTBEAT_REQUEST',
        request,
        'command.G2CHeartbeatResponse'
    );
}

module.exports = sendHeartbeat; 