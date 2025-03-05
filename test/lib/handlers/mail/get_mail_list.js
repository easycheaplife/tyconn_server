// 获取邮件列表处理器
async function getMailList() {
    // 构造请求数据
    const request = {
        token: this.token
    };

    // 发送请求
    return this.sendGameRequest(
        'C2G_MAIL_LIST_REQUEST',
        request,
        'command.G2CMailListResponse'
    );
}

module.exports = getMailList;