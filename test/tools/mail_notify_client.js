const LoginClient = require('../lib/login_client');
const GameClient = require('../lib/game_client');
const config = require('../config/config');
const ProtoHelper = require('../lib/proto_helper');

class MailNotifyClient {
    constructor() {
        this.user_id = null;
        this.token = null;
        this.protoHelper = null;
        this.gameClient = null;
        this.loginClient = new LoginClient();
        this.protoHelper = ProtoHelper.getInstance();
        // 生成随机账号
        this.account = `test_${Math.floor(Math.random() * 10000)}`;
        this.password = '123456';
        this.directConnect = false; // 是否直接连接到游戏服务器
    }

    async start(options = {}) {
        try {
            // 确保 proto 文件已加载
            await this.protoHelper.ensureInitialized();
            
            console.log('Connecting to server...');
            
            // 检查是否使用直接连接模式
            this.directConnect = options.directConnect || false;
            
            if (this.directConnect) {
                console.log('Using direct login to game server...');
                if (options.account) {
                    this.account = options.account;
                }
                console.log('Using account:', this.account);
                
                // 直接连接到游戏服务器
                await this.loginGame(options.serverInfo || config.gameServer);
            } else {
                console.log('Using account:', this.account);
                
                // 使用随机账号登录
                const loginResult = await this.loginClient.login(
                    this.account,
                    this.password
                );

                // 保存token
                this.token = loginResult.token;

                // 解析网关信息
                const serverInfo = {
                    protocol: 'ws',
                    host: loginResult.gateInfo.host,
                    port: loginResult.gateInfo.port
                };
                
                // 创建游戏客户端，直接传入认证信息
                this.gameClient = new GameClient(loginResult.token, serverInfo);
                
                // 连接
                await this.gameClient.connect();
            }
            
            // 连接成功后设置消息处理器
            this.setupMessageHandler();
            
            console.log('Connected to game server, requesting user info...');
            
            // 初始化用户信息
            await this.init();
            
            // 启动心跳
            this.startHeartbeat();
            
            console.log('Waiting for mail notifications...');
            
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
        // 导入心跳包处理器
        const sendHeartbeat = require('../lib/handlers/system/heartbeat');
        
        // 每30秒发送一次心跳
        this.heartbeatInterval = setInterval(async () => {
            try {
                // 使用绑定的sendHeartbeat方法
                await sendHeartbeat.call(this.gameClient, this.token);
                console.log('Heartbeat sent successfully.');
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

    // 初始化用户信息
    async init() {
        const userInfo = await this.getUserInfo();
        console.log('\nUser Info:');
        if (userInfo && userInfo.user) {
            // 正确获取user_id，处理可能的格式差异
            this.user_id = userInfo.user.user_id ? 
                (userInfo.user.user_id.low || userInfo.user.user_id) : 
                (userInfo.user.userId ? (userInfo.user.userId.low || userInfo.user.userId) : null);
            
            // 显示正确的用户信息
            console.log(`User ID: ${this.user_id}`);
            console.log(`Nickname: ${userInfo.user.username || 'N/A'}`);
            console.log(`Level: ${userInfo.user.level || 0}`);
            console.log('----------------------------------------');
            return true;
        } else {
            console.log('Failed to get user info');
            console.log('----------------------------------------');
            return false;
        }
    }

    // 发送系统邮件
    async sendSystemMail(title, content, items = []) {
        const messageId = this.protoHelper.MessageID.C2G_SEND_SYSTEM_MAIL_REQUEST;
        const response = await this.gameClient.sendGameRequest(
            messageId,
            {
                title,
                content,
                items: items.map(item => ({
                    itemId: item.item_id,
                    count: item.count
                }))
            },
            'command.G2CSendSystemMailResponse'
        );
        return response;
    }

    // 获取邮件列表
    async getMailList() {
        const messageId = this.protoHelper.MessageID.C2G_MAIL_LIST_REQUEST;
        const response = await this.gameClient.sendGameRequest(
            messageId,
            {},
            'command.G2CMailListResponse'
        );
        return response;
    }

    // 读取邮件
    async readMail(mailId) {
        const messageId = this.protoHelper.MessageID.C2G_READ_MAIL_REQUEST;
        const response = await this.gameClient.sendGameRequest(
            messageId,
            {
                mailId
            },
            'command.G2CReadMailResponse'
        );
        return response;
    }

    // 直接登录到游戏服务器
    async loginGame(serverInfo) {
        try {
            console.log('Direct login to game server...');
            
            // 创建游戏客户端，但不传入token
            this.gameClient = new GameClient(null, serverInfo);
            
            // 连接到游戏服务器
            await this.gameClient.connect();
            
            // 发送登录请求
            const messageId = this.protoHelper.MessageID.C2G_LOGIN_GAME_REQUEST;
            const response = await this.gameClient.sendGameRequest(
                messageId,
                {
                    account: this.account,
                    password: this.password
                },
                'command.G2CLoginGameResponse'
            );
            
            if (!response || !response.token) {
                throw new Error('Failed to login to game server: Invalid response');
            }
            
            // 保存token
            this.token = response.token;
            this.gameClient.token = response.token;
            
            console.log('Successfully logged in to game server');
            return true;
        } catch (error) {
            console.error('Failed to login to game server:', error);
            throw error;
        }
    }
}

// 启动客户端
const client = new MailNotifyClient();
client.start().catch(error => {
    console.error('Failed to start client:', error);
    process.exit(1);
}); 