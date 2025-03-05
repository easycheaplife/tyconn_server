const LoginClient = require('../lib/login_client');
const GameClient = require('../lib/game_client');
const config = require('../config/config');
const ProtoHelper = require('../lib/proto_helper');

class MailNotifyClient {
    constructor() {
        this.loginClient = new LoginClient();
        this.gameClient = new GameClient();
        this.protoHelper = ProtoHelper.getInstance();
        // 生成随机账号
        this.account = `test_${Math.floor(Math.random() * 10000)}`;
        this.password = '123456';
    }

    async start() {
        try {
            // 确保 proto 文件已加载
            await this.protoHelper.ensureInitialized();
            
            console.log('Connecting to server...');
            console.log('Using account:', this.account);
            
            // 使用随机账号登录
            const loginResult = await this.loginClient.login(
                this.account,
                this.password
            );

            // 解析网关信息
            const serverInfo = {
                protocol: 'ws',
                host: loginResult.gateInfo.host,
                port: loginResult.gateInfo.port
            };

            // 先设置认证信息
            this.gameClient.setAuth(loginResult.token, serverInfo);
            
            // 然后连接
            await this.gameClient.connect();

            // 重新设置认证信息，确保使用最新的 token
            this.gameClient.setAuth(loginResult.token, serverInfo);
            
            // 连接成功后设置消息处理器
            this.setupMessageHandler();
            
            console.log('Connected to game server, requesting user info...');

            // 等待一下确保连接稳定
            await new Promise(resolve => setTimeout(resolve, 1000));

            // 获取用户信息
            try {
                const userInfo = await this.getUserInfo();
                console.log('\nUser Info:');
                console.log('User ID:', userInfo.user.userId);
                console.log('Nickname:', userInfo.user.nickname);
                console.log('Level:', userInfo.user.level);
                console.log('----------------------------------------');
            } catch (error) {
                console.error('Failed to get user info:', error);
            }
            
            console.log('Waiting for mail notifications...');
            
            // 保持连接
            this.startHeartbeat();
            
            // 监听 SIGINT 信号以优雅退出
            process.on('SIGINT', () => {
                console.log('\nReceived SIGINT, closing connection...');
                this.stop();
                process.exit(0);
            });

        } catch (error) {
            console.error('Failed to start mail notify client:', error);
            console.error('Error details:', error.stack);
            process.exit(1);
        }
    }

    // 获取用户信息
    async getUserInfo() {
        const messageId = this.protoHelper.MessageID.C2G_USER_INFO_REQUEST;
        const response = await this.gameClient.sendGameRequest(
            messageId,
            {
                token: this.gameClient.token  // 添加 token 到请求中
            },
            'command.G2CUserInfoResponse'
        );
        return response;
    }

    setupMessageHandler() {
        if (this.gameClient.ws) {
            this.gameClient.ws.on('message', (data) => {
                try {
                    const response = this.gameClient.handleResponse(data);
                    this.handleMessage(response.session.messageId, response.payload);
                } catch (error) {
                    console.error('Error handling message:', error);
                }
            });
        } else {
            console.warn('WebSocket not initialized yet');
            // 等待连接完成后再次尝试设置处理器
            setTimeout(() => {
                if (this.gameClient.ws) {
                    this.setupMessageHandler();
                }
            }, 100);
        }
    }

    handleMessage(messageId, data) {
        // 处理新邮件推送
        const NEW_MAIL_PUSH = this.protoHelper.MessageID.G2C_NEW_MAIL_PUSH;
        if (messageId === NEW_MAIL_PUSH) {
            const timestamp = new Date().toISOString();
            console.log('\n[%s] Received new mail notification:', timestamp);
            console.log('Mail ID:', data.mail.id);
            console.log('Title:', data.mail.title);
            console.log('Type:', data.mail.mail_type === 1 ? 'System Mail' : 'Personal Mail');
            console.log('Has Items:', data.mail.has_items ? 'Yes' : 'No');
            console.log('----------------------------------------');
        } else {
            console.log('Received message ID:', messageId);
            if (data) {
                console.log('Message data:', JSON.stringify(data, null, 2));
            }
        }
    }

    async startHeartbeat() {
        // 每30秒发送一次心跳
        this.heartbeatInterval = setInterval(async () => {
            try {
                await this.gameClient.sendHeartbeat();
            } catch (error) {
                console.error('Heartbeat failed:', error);
                console.error('Error details:', error.stack);
                this.stop();
                process.exit(1);
            }
        }, 30000);
    }

    stop() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
        }
        if (this.gameClient) {
            this.gameClient.close();
        }
    }
}

// 启动客户端
const client = new MailNotifyClient();
client.start().catch(error => {
    console.error('Failed to start client:', error);
    process.exit(1);
}); 