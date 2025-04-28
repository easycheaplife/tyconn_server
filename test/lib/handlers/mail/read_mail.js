// 读取邮件处理器
async function readMail(mailId) {
    const request = {
        token: this.token,
        mail_id: mailId
    };

    return this.sendGameRequest(
        'C2G_READ_MAIL_REQUEST',
        request,
        'command.G2CReadMailResponse'
    );
}

module.exports = readMail;