class RequestBuilder {
    static buildBaseRequest(root, messageId, payload) {
        const baseRequest = {
            session: {
                messageId: messageId,
                sequence: 1,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: payload
        };

        console.log('\n[请求] 基础信息:', baseRequest);

        return root.lookupType("common.BaseRequest")
            .encode(baseRequest)
            .finish();
    }

    static buildLoginRequest(root, account, password, deviceId, platform) {
        const loginRequest = {
            account: account,
            password: password,
            device_id: deviceId,
            platform: platform
        };

        console.log('\n[Login] 请求详情:', loginRequest);

        const payload = root.lookupType("command.C2LLoginRequest")
            .encode(loginRequest)
            .finish();

        return this.buildBaseRequest(
            root,
            root.lookupEnum("common.MessageID").values.C2L_LOGIN_REQUEST,
            payload
        );
    }

    static buildUserInfoRequest(root, token) {
        const userInfoRequest = {
            token: token
        };

        console.log('\n[UserInfo] 请求详情:', userInfoRequest);

        const payload = root.lookupType("command.C2GUserInfoRequest")
            .encode(userInfoRequest)
            .finish();

        return this.buildBaseRequest(
            root,
            root.lookupEnum("common.MessageID").values.C2G_USER_INFO_REQUEST,
            payload
        );
    }

    static buildHeartbeatRequest(root, token) {
        const heartbeatRequest = {
            token: token,
            timestamp: Math.floor(Date.now() / 1000)
        };

        console.log('\n[Heartbeat] 请求详情:', heartbeatRequest);

        const payload = root.lookupType("command.C2GHeartbeat")
            .encode(heartbeatRequest)
            .finish();

        return this.buildBaseRequest(
            root,
            root.lookupEnum("common.MessageID").values.C2G_HEARTBEAT_REQUEST,
            payload
        );
    }
}

module.exports = RequestBuilder; 