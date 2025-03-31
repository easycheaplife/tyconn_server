// 领取通关奖励处理器
async function claimReward() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        this.protoHelper.MessageID.C2G_CLAIM_REWARD_REQUEST,
        request,
        'command.G2CClaimRewardResponse'
    );
}

module.exports = claimReward; 