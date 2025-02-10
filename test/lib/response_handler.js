const ProtoHelper = require('./proto_helper');

class ResponseHandler {
    constructor(root) {
        this.root = root;
    }

    decodeBaseResponse(data, msgType) {
        try {
            if (!data) {
                console.error('No data to decode');
                return null;
            }

            const baseResponse = ProtoHelper.decodeMessage(this.root, 'common.BaseResponse', data);
            if (!baseResponse) {
                console.error('Failed to decode BaseResponse');
                return null;
            }

            if (!baseResponse.session) {
                console.error('BaseResponse has no session');
                return null;
            }

            // 打印完整的响应信息
            console.log(`\n[${msgType || 'Unknown'}] Base response:`, JSON.stringify({
                session: {
                    messageId: baseResponse.session.messageId,
                    sequence: baseResponse.session.sequence,
                    timestamp: baseResponse.session.timestamp,
                    version: baseResponse.session.version
                },
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg,
                payload: baseResponse.payload ? {
                    length: baseResponse.payload.length,
                    hex: baseResponse.payload.toString('hex'),
                    text: (() => {
                        try {
                            return baseResponse.payload.toString('utf8');
                        } catch (e) {
                            return 'Not UTF-8 text';
                        }
                    })()
                } : 'null'
            }, null, 2));

            return baseResponse;
        } catch (err) {
            console.error('Failed to decode base response:', err);
            if (data) {
                console.error('Data length:', data.length);
                console.error('Data (hex):', data.toString('hex'));
            }
            return null;
        }
    }

    handleLoginResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'Login');
        if (!baseResponse) {
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('登录失败:', baseResponse.errorMsg || '未知错误');
            return null;
        }

        const loginResponse = ProtoHelper.decodeMessage(
            this.root,
            'command.S2LLoginResponse',
            baseResponse.payload
        );

        console.log('Login response:', {
            code: loginResponse.code,
            message: loginResponse.message,
            token: loginResponse.token ? loginResponse.token.substring(0, 20) + '...' : null,
            ws_addr: loginResponse.ws_addr,
            ws_port: loginResponse.ws_port
        });

        return loginResponse;
    }

    handleUserInfoResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'UserInfo');
        if (!baseResponse) {
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('获取用户信息失败:', baseResponse.errorMsg);
            return null;
        }

        const userInfoResponse = ProtoHelper.decodeMessage(
            this.root,
            'command.G2CUserInfoResponse',
            baseResponse.payload
        );

        console.log('\n用户信息:', userInfoResponse.user);
        console.log('是否新用户:', userInfoResponse.is_new);

        return userInfoResponse;
    }

    handleHeartbeatResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'Heartbeat');
        if (!baseResponse) {
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('心跳失败:', baseResponse.errorMsg);
            return null;
        }

        if (baseResponse.payload && baseResponse.payload.length > 0) {
            try {
                const heartbeatResponse = ProtoHelper.decodeMessage(
                    this.root,
                    'command.G2CHeartbeat',
                    baseResponse.payload
                );
                console.log('Heartbeat response:', {
                    timestamp: heartbeatResponse.timestamp,
                    code: heartbeatResponse.code
                });
                return heartbeatResponse;
            } catch (err) {
                console.error('Failed to decode heartbeat response:', err);
                return null;
            }
        }

        return true;
    }
}

module.exports = ResponseHandler; 