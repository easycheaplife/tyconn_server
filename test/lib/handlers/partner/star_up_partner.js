// 伙伴升星处理器
async function starUpPartner(partnerId) {
    const request = {
        token: this.token,
        partner_id: partnerId
    };
    
    return this.sendGameRequest(
        'C2G_PARTNER_STAR_UP_REQUEST',
        request,
        'command.G2CPartnerStarUpResponse'
    );
}

module.exports = starUpPartner; 