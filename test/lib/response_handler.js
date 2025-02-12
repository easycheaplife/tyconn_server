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

            // 解码基础响应
            const baseResponse = ProtoHelper.decodeMessage(
                this.root,
                'common.BaseResponse',
                data
            );

            if (!baseResponse) {
                console.error('Failed to decode BaseResponse');
                return null;
            }

            // 打印完整的响应信息
            console.log(`\n[${msgType}] 响应:`, {
                session: baseResponse.session ? {
                    messageId: baseResponse.session.messageId,
                    sequence: baseResponse.session.sequence,
                    timestamp: baseResponse.session.timestamp,
                    version: baseResponse.session.version
                } : null,
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg,
                payload: baseResponse.payload ? {
                    length: baseResponse.payload.length,
                    hex: baseResponse.payload.toString('hex')
                } : null
            });

            return baseResponse;

        } catch (err) {
            console.error('Failed to decode base response:', err);
            if (data) {
                console.error('Raw data (hex):', data.toString('hex'));
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
            console.log('登录失败:', {
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg
            });
            return null;
        }

        const loginResponse = ProtoHelper.decodeMessage(
            this.root,
            'command.S2LLoginResponse',
            baseResponse.payload
        );

        console.log('\n[Login] 响应详情:', {
            session: baseResponse.session,
            errorCode: baseResponse.errorCode,
            errorMsg: baseResponse.errorMsg,
            payload: {
                code: loginResponse.code,
                message: loginResponse.message,
                token: loginResponse.token ? loginResponse.token.substring(0, 20) + '...' : null,
                ws_addr: loginResponse.ws_addr,
                ws_port: loginResponse.ws_port
            }
        });

        return loginResponse;
    }

    handleUserInfoResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'UserInfo');
        if (!baseResponse) {
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('获取用户信息失败:', {
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg
            });
            return null;
        }

        const userInfoResponse = ProtoHelper.decodeMessage(
            this.root,
            'command.G2CUserInfoResponse',
            baseResponse.payload
        );

        console.log('\n[UserInfo] 响应详情:', {
            session: baseResponse.session,
            errorCode: baseResponse.errorCode,
            errorMsg: baseResponse.errorMsg,
            payload: {
                code: userInfoResponse.code,
                message: userInfoResponse.message,
                user: {
                    user_id: userInfoResponse.user.user_id.toString(),
                    username: userInfoResponse.user.username,
                    level: userInfoResponse.user.level,
                    exp: userInfoResponse.user.exp.toString(),
                    vip_level: userInfoResponse.user.vip_level,
                    create_time: userInfoResponse.user.create_time ? 
                        new Date(Number(userInfoResponse.user.create_time) * 1000).toLocaleString() : 'N/A',
                    login_time: userInfoResponse.user.login_time ? 
                        new Date(Number(userInfoResponse.user.login_time) * 1000).toLocaleString() : 'N/A'
                },
                is_new: userInfoResponse.is_new
            }
        });

        return userInfoResponse;
    }

    handleHeartbeatResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'Heartbeat');
        if (!baseResponse) {
            console.log('无法解析响应消息');
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('心跳请求失败:', {
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg
            });
            return null;
        }

        if (baseResponse.payload && baseResponse.payload.length > 0) {
            try {
                const heartbeatResponse = ProtoHelper.decodeMessage(
                    this.root,
                    'command.G2CHeartbeat',
                    baseResponse.payload
                );

                console.log('\n[Heartbeat] 响应详情:', {
                    session: baseResponse.session,
                    errorCode: baseResponse.errorCode,
                    errorMsg: baseResponse.errorMsg,
                    payload: {
                        timestamp: heartbeatResponse.timestamp,
                        code: heartbeatResponse.code
                    }
                });

                return heartbeatResponse;
            } catch (err) {
                console.error('解析心跳响应失败:', err);
                return null;
            }
        }

        return true;
    }

    handleCardBagResponse(data) {
        const baseResponse = this.decodeBaseResponse(data, 'CardBag');
        if (!baseResponse) {
            console.error("Failed to decode base response");
            return null;
        }

        if (baseResponse.errorCode !== 0) {
            console.log('获取背包失败:', {
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg
            });
            return null;
        }

        try {
            const cardBagResponse = ProtoHelper.decodeMessage(
                this.root,
                'command.G2CUserCardBagResponse',
                baseResponse.payload
            );

            console.log('\n[CardBag] 响应详情:', {
                session: baseResponse.session,
                errorCode: baseResponse.errorCode,
                errorMsg: baseResponse.errorMsg,
                cardCount: cardBagResponse.cards ? cardBagResponse.cards.length : 0
            });

            return {
                code: cardBagResponse.code,
                message: cardBagResponse.message,
                cards: cardBagResponse.cards || []
            };
        } catch (err) {
            console.error('解析背包响应失败:', err);
            return null;
        }
    }
}

module.exports = ResponseHandler; 