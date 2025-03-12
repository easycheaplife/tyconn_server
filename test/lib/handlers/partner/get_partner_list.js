// 获取伙伴列表处理器
async function getPartnerList() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        'C2G_PARTNER_LIST_REQUEST',
        request,
        'command.G2CPartnerListResponse'
    );
}

module.exports = getPartnerList; 