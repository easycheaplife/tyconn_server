// 掷骰子处理器
async function rollDice() {
    const request = {
        token: this.token
    };

    return this.sendGameRequest(
        this.protoHelper.MessageID.C2G_ROLL_DICE_REQUEST,
        request,
        'command.G2CRollDiceResponse'
    );
}

module.exports = rollDice; 