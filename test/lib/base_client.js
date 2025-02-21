const WebSocket = require('ws');
const ProtoHelper = require('./proto_helper');
const config = require('../config/config');

class BaseClient {
    constructor() {
        this.ws = null;
        this.protoHelper = new ProtoHelper();
        this.token = null;
        this.serverInfo = null;
        this.connected = false;
    }

    // 设置token和服务器信息
    setAuth(token, serverInfo) {
        this.token = token;
        this.serverInfo = serverInfo;
    }

    // 连接到服务器
    async connect() {
        if (!this.serverInfo) {
            throw new Error('Server info not set');
        }

        // 确保proto已初始化
        if (!this.protoHelper.initialized) {
            await this.protoHelper.init();
        }

        const wsUrl = `${this.serverInfo.protocol}://${this.serverInfo.host}:${this.serverInfo.port}`;
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(wsUrl, {
                rejectUnauthorized: false
            });

            this.ws.on('open', () => {
                console.log('Connected to server:', wsUrl);
                resolve();
            });

            this.ws.on('error', (error) => {
                console.error('WebSocket error:', error);
                reject(error);
            });

            this.ws.on('close', () => {
                console.log('Disconnected from server');
            });
        });
    }

    // 处理响应
    handleResponse(data) {
        try {
            const response = this.protoHelper.decodeBaseResponse(data);
            
            // 打印响应信息
            console.log('\nResponse details:');
            console.log('Session:', JSON.stringify(response.session, null, 2));
            console.log('Error code:', response.errorCode);
            
            // 获取错误码名称
            const errorName = response.errorCode !== 0 ? 
                this.protoHelper.getErrorCodeName(response.errorCode) : 'SUCCESS';
            console.log('Error name:', errorName);
            console.log('Error message:', response.errorMsg || 'Success');
            console.log('Raw payload:', response.payload);
            
            // 检查错误码
            if (response.errorCode !== 0) {
                const error = new Error(response.errorMsg || `Error: ${errorName}`);
                error.response = response;
                error.errorCode = response.errorCode;
                error.errorName = errorName;
                error.details = {
                    session: response.session,
                    errorCode: response.errorCode,
                    errorName: errorName,
                    errorMsg: response.errorMsg
                };
                throw error;
            }

            return response;
        } catch (error) {
            if (error.errorCode !== undefined) {
                // 已经处理过的错误，直接抛出
                throw error;
            }
            // 其他错误（如解码错误）
            console.error('Failed to handle response:', error);
            throw new Error(`Failed to handle response: ${error.message}`);
        }
    }

    // 发送请求并等待响应
    async sendRequest(messageId, requestData) {
        if (!this.ws) {
            throw new Error('Not connected to server');
        }

        // 等待 protoHelper 初始化完成
        if (!this.protoHelper.initialized) {
            await this.protoHelper.init();
        }

        // 验证消息ID
        if (!messageId) {
            console.error("No message ID provided!");
            console.log("Available message IDs:", 
                Object.entries(this.protoHelper.MessageID)
                    .map(([k,v]) => `${k}=${v}`)
                    .join(", "));
            throw new Error("Message ID is required");
        }

        const request = this.protoHelper.buildBaseRequest(messageId, requestData);
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                reject(new Error('Request timeout'));
            }, config.requestTimeout || 5000);

            this.ws.once('message', (data) => {
                clearTimeout(timeout);
                try {
                    const response = this.handleResponse(data);
                    resolve(response);
                } catch (error) {
                    reject(error);
                }
            });

            this.ws.send(request);
        });
    }

    // 关闭连接
    close() {
        if (this.ws) {
            try {
                this.ws.close();
            } catch (error) {
                // 忽略关闭时的错误
            }
            this.ws = null;
            this.connected = false;
        }
    }
}

module.exports = BaseClient; 