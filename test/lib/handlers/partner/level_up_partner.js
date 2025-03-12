// 伙伴升级处理器
async function levelUpPartner(partnerId) {
    const request = {
        token: this.token,
        partner_id: partnerId
    };

    return this.sendGameRequest(
        'C2G_PARTNER_LEVEL_UP_REQUEST',
        request,
        'command.G2CPartnerLevelUpResponse'
    );
}

module.exports = levelUpPartner; 