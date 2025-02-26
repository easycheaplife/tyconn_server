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

    try {
        // 发送GM命令请求
        const response = await this.sendGameRequest(
            'C2G_GM_COMMAND_REQUEST',
            {
                token: this.token,
                command,
                params      
            },
            'command.G2CGmCommandResponse'
        );

        // 检查响应结果
        if (!response.result) {
            throw new Error(response.message || 'GM command failed');
        }

        return response;
    } catch (err) {
        // 添加更多上下文信息到错误
        const error = new Error(`Failed to execute GM command ${command}: ${err.message}`);
        error.command = command;
        error.params = params;
        error.cause = err;
        throw error;
    }
}

module.exports = gmCommand; 