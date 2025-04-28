// 游戏登录处理器
async function loginGame() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        'C2G_LOGIN_GAME_REQUEST',
        request,
        'command.G2CLoginGameResponse'
    );
}

module.exports = loginGame; 