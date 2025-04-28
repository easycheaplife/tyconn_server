// 领取邮件附件处理器
async function claimMailItems(mailId) {
    const request = {
        token: this.token,
        mail_id: mailId
    };

    return this.sendGameRequest(
        'C2G_CLAIM_MAIL_ITEMS_REQUEST',
        request,
        'command.G2CClaimMailItemsResponse'
    );
}

module.exports = claimMailItems;