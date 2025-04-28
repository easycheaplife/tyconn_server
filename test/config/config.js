const SERVER_HOST = process.env.SERVER_HOST || '127.0.0.1';
const WS_PORT = process.env.WS_PROTOCOL === 'wss' ? '8009' : '8021';
const WS_PROTOCOL = process.env.WS_PROTOCOL || 'ws';

// SSL配置
const SSL_CONFIG = {
    rejectUnauthorized: process.env.SSL_REJECT_UNAUTHORIZED === 'true',  // 是否验证证书
    ca: process.env.SSL_CA_FILE,                                        // CA证书文件
    cert: process.env.SSL_CERT_FILE,                                    // 客户端证书
    key: process.env.SSL_KEY_FILE                                       // 客户端私钥
};

module.exports = {
    // 服务器配置
    protocol: WS_PROTOCOL,
    loginHost: SERVER_HOST,
    loginPort: WS_PORT,

    // 客户端配置
    platform: 'test',
    version: '1.0.0',
    requestTimeout: 5000,

    // 测试配置
    testAccount: 'test',
    testPassword: '123456',

    loginServer: `${WS_PROTOCOL}://${SERVER_HOST}:${WS_PORT}`,
    deviceId: 'test_device',
    jwtSecret: 'tyconn_jwt_secret',  // 添加JWT密钥，需要和服务器端一致
    ssl: WS_PROTOCOL === 'wss' ? SSL_CONFIG : undefined  // 仅在wss时使用SSL配置
}; 