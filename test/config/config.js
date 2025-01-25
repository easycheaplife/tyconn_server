const SERVER_HOST = process.env.SERVER_HOST || '127.0.0.1';

module.exports = {
    loginServer: `ws://${SERVER_HOST}:8021`,
    account: 'test',
    password: '123456',
    deviceId: 'test_device',
    platform: 'test',
    version: '1.0.0'
}; 