// 伙伴解锁处理器
async function unlockPartner(unitId) {
    const request = {
        token: this.token,
        unit_id: unitId
    };

    return this.sendGameRequest(
        'C2G_PARTNER_UNLOCK_REQUEST',
        request,
        'command.G2CPartnerUnlockResponse'
    );
}

module.exports = unlockPartner; 