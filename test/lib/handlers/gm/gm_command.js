/** * GM命令处理器
 * @param {string} command - GM命令
 * @param {string[]} params - 命令参数
 * @returns {Promise<object>} 响应结果
 */
async function gmCommand(command, params) {
    // 参数检查
    if (!command) {
        throw new Error('Command is required');
    }
    if (!Array.isArray(params)) {
        throw new Error('Params must be an array');
    }

    // 发送GM命令请求
    return await this.sendGameRequest(
        'C2G_GM_COMMAND_REQUEST',
        {
            token: this.token,
            command,
            params      
        },
        'command.G2CGmCommandResponse'
    );
}

module.exports = gmCommand; 