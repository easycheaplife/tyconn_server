const BaseClient = require('./base_client');
const handlers = require('./handlers');

class GameClient extends BaseClient {
    constructor(token, serverInfo) {
        super();
        // 设置认证信息
        if (token && serverInfo) {
            this.setAuth(token, serverInfo);
        }
        
        // 初始化处理器
        this.handlers = {};
        this.loadHandlers();
    }

    // 设置认证信息
    setAuth(token, serverInfo) {
        this.token = token;
        this.serverInfo = serverInfo;
    }

    // 加载所有处理器
    loadHandlers() {
        // 注册所有处理器
        for (const [name, handler] of Object.entries(handlers)) {
            this.registerHandler(name, handler);
        }
    }

    // 注册处理器
    registerHandler(name, handler) {
        if (this[name]) {
            throw new Error(`Handler already exists: ${name}`);
        }
        this[name] = handler.bind(this);
        this.handlers[name] = handler;
    }

    // 通用请求方法
    async sendGameRequest(messageId, requestData, responseType) {
        try {
            // 确保已经初始化
            if (!this.protoHelper.initialized) {
                await this.protoHelper.init();
            }
            console.log('sendGameRequest requestData', requestData);
            const response = await this.sendRequest(messageId, requestData);
            const result = this.decodeResponse(response, responseType);
            //console.log('sendGameRequest responseData', result);
            return result;
        } catch (error) {
            // 如果是已知错误，添加更多上下文信息
            if (error.errorCode !== undefined) {
                console.error(`Game request failed (${error.errorName}):`, {
                    messageId,
                    errorCode: error.errorCode,
                    errorMsg: error.message,
                    details: error.details
                });
            } else {
                console.error(`Failed to send game request: ${messageId}`, error);
            }
            throw error;
        }
    }

    // 解码响应
    decodeResponse(response, responseType) {
        // 检查基础响应中的错误码
        if (response.errorCode !== 0) {
            console.error('Request failed with error code:', response.errorCode);
            throw new Error(`Request failed: ${response.errorMsg || 'Unknown error'}`);
        }

        if (!response.payload) {
            console.error('Empty response payload');
            throw new Error('Empty response payload');
        }

        try {
            // 获取消息类型定义
            const messageType = this.protoHelper.root.lookupType(responseType);
            console.log('\nMessage type fields:', messageType.toJSON().fields);

            // 解码消息
            const decoded = this.protoHelper.decodeMessage(responseType, response.payload);
            
            // 显示完整字段，包括默认值和未设置的字段
            const fullFields = this.getFullFields(messageType, decoded);
            console.log('Decoded payload (with all fields):', JSON.stringify(fullFields, null, 2));
            
            return decoded;
        } catch (error) {
            console.error('Failed to decode response:', error);
            throw error;
        }
    }

    // 获取完整字段（包括默认值）
    getFullFields(messageType, decoded) {
        const fullFields = {};
        for (const [fieldName, field] of Object.entries(messageType.fields)) {
            if (fieldName === 'user' && decoded[fieldName]) {
                const userType = this.protoHelper.root.lookupType('common.UserInfo');
                fullFields[fieldName] = this.getFullFields(userType, decoded[fieldName]);
            } else {
                fullFields[fieldName] = decoded[fieldName] ?? 
                    (field.type === 'string' ? '' : 
                     field.type === 'bool' ? false : 0);
            }
        }
        return fullFields;
    }
}

module.exports = GameClient; 