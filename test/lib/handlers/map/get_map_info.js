// 获取地图信息处理器
async function getMapInfo() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        this.protoHelper.MessageID.C2G_MAP_INFO_REQUEST,
        request,
        'command.G2CMapInfoResponse'
    );
}

module.exports = getMapInfo;