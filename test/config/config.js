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
    loginServer: `${WS_PROTOCOL}://${SERVER_HOST}:${WS_PORT}`,
    account: 'test',
    password: '123456',
    deviceId: 'test_device',
    platform: 'test',
    version: '1.0.0',
    ssl: WS_PROTOCOL === 'wss' ? SSL_CONFIG : undefined  // 仅在wss时使用SSL配置
}; 