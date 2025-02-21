// 获取用户卡牌处理器
async function getUserCards() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        'C2G_USER_CARDS_REQUEST',
        request,
        'command.G2CUserCardsResponse'
    );
}

module.exports = getUserCards; 