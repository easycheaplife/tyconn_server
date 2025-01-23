const ProtoHelper = require('./proto_helper');

class ResponseHandler {
    constructor(root) {
        this.root = root;
    }

    handleLoginResponse(data) {
        const baseResponse = ProtoHelper.decodeMessage(this.root, 'common.BaseResponse', data);
        console.log('Base response:', {
            errorCode: baseResponse.errorCode,
            errorMsg: baseResponse.errorMsg
        });

        if (baseResponse.errorCode !== 0) {
            console.log('\n登录失败:', baseResponse.errorMsg);
            return null;
        }

        if (!baseResponse.payload || baseResponse.payload.length === 0) {
            console.log('\n登录响应无数据');
            return null;
        }

        const loginResponse = ProtoHelper.decodeMessage(
            this.root, 
            'command.S2LLoginResponse', 
            baseResponse.payload
        );

        console.log('Login response:', {
            token: loginResponse.token,
            ws_addr: loginResponse.ws_addr,
            ws_port: loginResponse.ws_port
        });

        return loginResponse;
    }

    handleUserInfoResponse(data) {
        const baseResponse = ProtoHelper.decodeMessage(this.root, 'common.BaseResponse', data);
        console.log('Base response:', {
            errorCode: baseResponse.errorCode,
            errorMsg: baseResponse.errorMsg
        });

        if (baseResponse.errorCode !== 0) {
            console.log('\n获取用户信息失败:', baseResponse.errorMsg);
            return null;
        }

        if (!baseResponse.payload || baseResponse.payload.length === 0) {
            console.log('\n用户信息响应无数据');
            return null;
        }

        const userInfoResponse = ProtoHelper.decodeMessage(
            this.root, 
            'command.G2CUserInfoResponse', 
            baseResponse.payload
        );

        console.log('User info response:', userInfoResponse);
        return userInfoResponse;
    }

    handleHeartbeatResponse(data) {
        const baseResponse = ProtoHelper.decodeMessage(this.root, 'common.BaseResponse', data);
        console.log('Heartbeat response:', {
            errorCode: baseResponse.errorCode,
            errorMsg: baseResponse.errorMsg
        });

        if (baseResponse.errorCode !== 0) {
            console.log('\n心跳失败:', baseResponse.errorMsg);
            return null;
        }

        if (baseResponse.payload && baseResponse.payload.length > 0) {
            const heartbeatResponse = ProtoHelper.decodeMessage(
                this.root,
                'command.G2CHeartbeat',
                baseResponse.payload
            );
            console.log('Heartbeat timestamp:', heartbeatResponse.timestamp);
        }

        return true;
    }
}

module.exports = ResponseHandler; 