// 获取用户信息处理器
async function getUserInfo() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        'C2G_USER_INFO_REQUEST',
        request,
        'command.G2CUserInfoResponse'
    );
}

module.exports = getUserInfo; 