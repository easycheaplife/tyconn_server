const protobuf = require('protobufjs');
const path = require('path');
const fs = require('fs');

class ProtoHelper {
    constructor() {
        this.root = null;
        this.MessageID = null;
        this.initialized = false;
        this.sequence = 0;
        this.init();
    }

    async init() {
        if (this.initialized) return;

        try {
            // 加载proto文件
            this.root = new protobuf.Root();
            
            // 设置 proto 文件搜索路径
            const protoPath = path.join(__dirname, '../../proto');
            this.root.resolvePath = (origin, target) => {
                if (path.isAbsolute(target)) {
                    return target;
                }
                return path.resolve(protoPath, target);
            };

            // 只加载必要的 proto 文件
            const protoFiles = [
                'common/message.proto',
                'common/error.proto',
                'command/command.proto'
            ];

            // 验证文件是否存在
            for (const file of protoFiles) {
                const fullPath = path.join(protoPath, file);
                if (!fs.existsSync(fullPath)) {
                    throw new Error(`Proto file not found: ${fullPath}`);
                }
            }

            // 加载文件
            console.log('Loading proto files...');
            for (const file of protoFiles) {
                const fullPath = path.join(protoPath, file);
                console.log(`Loading: ${file}`);
                await this.root.load(fullPath, {
                    keepCase: true,
                    alternateCommentMode: true,
                    preferTrailingComment: true
                });
            }

            // 解析所有类型
            console.log('Resolving types...');
            this.root.resolveAll();
            
            // 加载消息ID
            this.MessageID = this.root.lookupEnum('common.MessageID').values;
            console.log('Proto files loaded successfully');
            console.log('Available message IDs:', Object.keys(this.MessageID));

            this.initialized = true;
        } catch (error) {
            console.error('Failed to load proto files:', error);
            if (error.code === 'ENOENT') {
                console.error('Required proto files:');
                console.error('proto/');
                console.error('  ├── common/');
                console.error('  │   ├── message.proto');
                console.error('  │   └── error.proto');
                console.error('  └── command/');
                console.error('      └── command.proto');
            }
            throw error;
        }
    }

    // 获取请求消息类型
    getRequestType(messageId) {
        // 如果是数字ID，先转换为字符串名称
        if (typeof messageId === 'number') {
            const messageNames = Object.entries(this.MessageID)
                .find(([name, id]) => id === messageId);
            if (!messageNames) {
                throw new Error(`Unknown message ID number: ${messageId}`);
            }
            messageId = messageNames[0];
        }

        const requestTypes = {
            'C2L_LOGIN_REQUEST': 'command.C2LLoginRequest',
            'C2G_HEARTBEAT_REQUEST': 'command.C2GHeartbeatRequest',
            'C2G_USER_INFO_REQUEST': 'command.C2GUserInfoRequest',
            'C2G_USER_CARD_BAG_REQUEST': 'command.C2GUserCardBagRequest',
            'C2G_BAG_INFO_REQUEST': 'command.C2GBagInfoRequest',
            'C2G_USE_ITEM_REQUEST': 'command.C2GUseItemRequest'  
        };

        const type = requestTypes[messageId];
        if (!type) {
            throw new Error(`Unknown message type for: ${messageId}`);
        }
        return type;
    }

    // 构建基础请求
    buildBaseRequest(messageId, payload) {
        if (!this.root) {
            throw new Error('Proto files not loaded');
        }

        // 验证消息ID是否有效
        if (typeof messageId === 'string') {
            if (!this.MessageID[messageId]) {
                throw new Error(`Invalid message ID string: ${messageId}`);
            }
            messageId = this.MessageID[messageId];
        }

        if (!Number.isInteger(messageId) || messageId <= 0) {
            console.error("Invalid message ID:", messageId);
            console.log("Available message IDs:", 
                Object.entries(this.MessageID)
                    .map(([k,v]) => `${k}=${v}`)
                    .join(", "));
            throw new Error(`Invalid message ID: ${messageId}`);
        }

        // 打印调试信息
        console.log("Processing message ID:", messageId);
        console.log("Message ID type:", typeof messageId);

        const BaseRequest = this.root.lookupType('common.BaseRequest');
        const messageType = this.root.lookupType(this.getRequestType(messageId));

        // 编码具体请求
        const encodedPayload = messageType.encode(payload).finish();

        // 创建基础请求
        const baseRequest = {
            session: {
                messageId: messageId,
                sequence: ++this.sequence,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: encodedPayload
        };

        console.log("Building request with message ID:", messageId);
        console.log("Request data:", baseRequest);

        // 编码基础请求
        return BaseRequest.encode(baseRequest).finish();
    }

    // 解码基础响应
    decodeBaseResponse(data) {
        const BaseResponse = this.root.lookupType('common.BaseResponse');
        return BaseResponse.decode(data);
    }

    // 解码登录响应
    decodeLoginResponse(payload) {
        // 使用正确的消息类型名称
        const LoginResponse = this.root.lookupType('command.S2LLoginResponse');
        return LoginResponse.decode(payload);
    }

    // 解码用户信息响应
    decodeUserInfoResponse(payload) {
        const UserInfoResponse = this.root.lookupType('command.G2CUserInfoResponse');
        return UserInfoResponse.decode(payload);
    }

    // 解码心跳响应
    decodeHeartbeatResponse(payload) {
        const HeartbeatResponse = this.root.lookupType('command.G2CHeartbeat');
        return HeartbeatResponse.decode(payload);
    }

    // 解码消息
    decodeMessage(messageType, payload) {
        const MessageType = this.root.lookupType(messageType);
        if (!MessageType) {
            throw new Error(`Message type not found: ${messageType}`);
        }
        return MessageType.decode(payload);
    }

    static async loadProtos() {
        // 获取项目根目录
        let rootDir = path.resolve(__dirname, '../..');
        
        // 检查 proto 目录是否存在
        const protoPath = path.join(rootDir, 'proto');
        if (!fs.existsSync(protoPath)) {
            throw new Error(`Proto directory not found: ${protoPath}`);
        }

        // 创建一个新的 Root 实例
        const root = new protobuf.Root();
        
        // 设置 proto 文件搜索路径
        root.resolvePath = (origin, target) => {
            if (path.isAbsolute(target)) {
                return target;
            }
            // 如果是相对路径，从 proto 目录开始查找
            return path.resolve(protoPath, target);
        };

        console.log('Loading proto files from:', protoPath);
        // 加载所有需要的 proto 文件
        await root.load([
            path.join(protoPath, 'common/message.proto'),
            path.join(protoPath, 'command/command.proto')
        ],
            {
                keepCase: true,
                alternateCommentMode: true,
                preferTrailingComment: true
            }
        );

        // 验证所有消息定义
        root.resolveAll();
        
        // 打印所有加载的类型
        console.log('Loaded types:');
        this.listTypes(root).forEach(type => console.log('  -', type));
        
        // 特别检查 MessageID 枚举
        const messageIdEnum = root.lookup('common.MessageID');
        if (messageIdEnum) {
            console.log('MessageID enum found:', messageIdEnum.values);
        } else {
            console.log('MessageID enum not found in loaded types');
        }

        return root;
    }

    static createMessage(root, messageName, data) {
        const MessageType = root.lookupType(messageName);
        if (!MessageType) {
            throw new Error(`Message type not found: ${messageName}`);
        }
        return MessageType.encode(data).finish();
    }

    static decodeMessage(root, messageName, buffer) {
        const MessageType = root.lookupType(messageName);
        if (!MessageType) {
            throw new Error(`Message type not found: ${messageName}`);
        }
        return MessageType.decode(buffer);
    }

    // 辅助方法：获取枚举值
    static getEnumValue(root, enumName, valueName) {
        const EnumType = root.lookupEnum(enumName);
        if (!EnumType) {
            throw new Error(`Enum not found: ${enumName}`);
        }
        const value = EnumType.values[valueName];
        if (value === undefined) {
            throw new Error(`Enum value not found: ${enumName}.${valueName}`);
        }
        return EnumType.values[valueName];
    }

    // 辅助方法：打印消息内容
    static printMessage(message) {
        return JSON.stringify(message.toJSON(), null, 2);
    }

    // 辅助方法：检查类型是否存在
    static hasType(root, typeName) {
        return !!root.lookup(typeName);
    }

    // 辅助方法：列出所有可用的类型
    static listTypes(root) {
        const types = [];
        root.nestedArray.forEach(nested => {
            if (nested instanceof protobuf.Type) {
                types.push(nested.fullName);
            } else if (nested instanceof protobuf.Enum) {
                types.push(`enum ${nested.fullName}`);
            }
        });
        return types;
    }

    // 添加调试方法
    listAvailableTypes() {
        const types = [];
        this.root.nestedArray.forEach(nested => {
            if (nested.nestedArray) {
                nested.nestedArray.forEach(type => {
                    types.push(`${nested.name}.${type.name}`);
                });
            }
        });
        return types;
    }
}

module.exports = ProtoHelper; 