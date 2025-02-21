// 获取背包信息处理器
async function getBagInfo() {
    const request = {
        token: this.token
    };

    // 打印请求信息
    console.log('\nSending bag info request:', request);

    return this.sendGameRequest(
        'C2G_BAG_INFO_REQUEST',
        request,
        'command.G2CBagInfoResponse'
    );
}

module.exports = getBagInfo; 