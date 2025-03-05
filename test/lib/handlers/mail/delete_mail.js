// 删除邮件处理器
async function deleteMail(mailId) {
    const request = {
        token: this.token,
        mail_id: mailId
    };

    return this.sendGameRequest(
        'C2G_DELETE_MAIL_REQUEST',
        request,
        'command.G2CDeleteMailResponse'
    );
}

module.exports = deleteMail;