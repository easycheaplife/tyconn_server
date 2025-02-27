const protobuf = require('protobufjs');
const path = require('path');
const fs = require('fs');

class ProtoHelper {
    static #instance = null;
    static #initPromise = null;

    static getInstance() {
        if (!this.#instance) {
            this.#instance = new ProtoHelper();
        }
        return this.#instance;
    }

    constructor() {
        if (ProtoHelper.#instance) {
            throw new Error('Use ProtoHelper.getInstance() instead');
        }
        this.root = null;
        this.MessageID = {};
        this.initialized = false;
        this.sequence = 0;
        this.ErrorCode = {};  // 改为空对象，等待动态加载
        this.BagType = {};  // 改为空对象，等待动态加载
    }

    async ensureInitialized() {
        if (this.initialized) {
            return;
        }

        if (ProtoHelper.#initPromise) {
            await ProtoHelper.#initPromise;
            return;
        }

        ProtoHelper.#initPromise = this.init();
        try {
            await ProtoHelper.#initPromise;
        } finally {
            ProtoHelper.#initPromise = null;
        }
    }

    async init() {
        if (this.initialized) return;

        try {
            // 加载proto文件
            console.log('Loading proto files...');
            this.root = new protobuf.Root();
            
            // 设置 proto 文件搜索路径
            const protoPath = path.join(__dirname, '../../proto');
            this.root.resolvePath = (origin, target) => {
                if (path.isAbsolute(target)) {
                    return target;
                }
                return path.resolve(protoPath, target);
            };

            // 扫描proto目录
            const protoFiles = await this.scanProtoDir(protoPath);
            console.log('Found proto files:', protoFiles);

            // 验证并加载文件
            for (const file of protoFiles) {
                const fullPath = path.join(protoPath, file);
                if (!fs.existsSync(fullPath)) {
                    throw new Error(`Proto file not found: ${fullPath}`);
                }
                console.log(`Loading: ${file}`);
                await this.root.load(file, {
                    keepCase: true,
                    alternateCommentMode: true
                });
            }

            // 解析所有类型
            console.log('Resolving types...');
            this.root.resolveAll();
            
            // 加载消息ID
            const MessageID = this.root.lookupEnum('common.MessageID');
            this.MessageID = MessageID.values;
            console.log('Proto files loaded successfully');
            console.log('Available message IDs:', Object.keys(this.MessageID));

            // 初始化错误码
            const ErrorCode = this.root.lookupEnum('common.ErrorCode');
            this.ErrorCode = ErrorCode.values;

            // 初始化背包类型
            const BagType = this.root.lookupEnum('common.BagType');
            this.BagType = BagType.values;
            console.log('Loaded BagType:', Object.keys(this.BagType));

            this.initialized = true;
        } catch (error) {
            console.error('Failed to load proto files:', error);
            throw error;
        }
    }

    // 扫描proto目录
    async scanProtoDir(dir) {
        const files = [];
        
        // 读取目录内容
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        
        // 处理每个条目
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                // 递归扫描子目录
                const subFiles = await this.scanProtoDir(fullPath);
                files.push(...subFiles);
            } else if (entry.isFile() && entry.name.endsWith('.proto')) {
                // 添加.proto文件，使用相对路径
                const relativePath = path.relative(path.join(__dirname, '../../proto'), fullPath);
                files.push(relativePath);
            }
        }

        return files;
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

        // 从消息ID名称自动生成消息类型名称
        // 例如: C2G_BAG_INFO_REQUEST -> command.C2GBagInfoRequest
        if (typeof messageId === 'string') {
            // 1. 移除 _REQUEST 后缀
            let typeName = messageId.replace(/_REQUEST$/, '');
            
            // 2. 保持前缀(C2L/C2G等)的大小写，将其他部分转换为驼峰命名
            const parts = typeName.split('_');
            const prefix = parts[0];  // C2L/C2G等
            const restParts = parts.slice(1);
            
            typeName = prefix + restParts.map(part => 
                part.charAt(0).toUpperCase() + part.slice(1).toLowerCase()
            ).join('');
            
            // 3. 添加Request后缀
            typeName += 'Request';

            // 4. 添加command.前缀
            const fullTypeName = `command.${typeName}`;

            // 验证类型是否存在
            try {
                if (this.root.lookupType(fullTypeName)) {
                    return fullTypeName;
                }
            } catch (error) {
                console.error(`Failed to lookup type: ${fullTypeName}`);
                console.error('Available types:', this.listAvailableTypes());
                throw error;
            }

            throw new Error(`Message type not found: ${fullTypeName} (from ${messageId})`);
        }

        throw new Error(`Invalid message ID type: ${typeof messageId}`);
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
        const LoginResponse = this.root.lookupType('command.L2CLoginResponse');
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

    // 加载所有枚举
    loadEnums() {
        const common = this.root.lookup('common');
        if (!common) {
            console.error('Root contents:', this.root);
            throw new Error('common package not found');
        }

        // 加载消息ID枚举
        const MessageID = common.lookupEnum('MessageID');
        if (MessageID) {
            this.MessageID = MessageID.values;
            console.log('Loaded MessageID enum:', this.MessageID);
        } else {
            console.warn('MessageID enum not found in common package');
        }

        // 加载错误码枚举
        const ErrorCode = common.lookupEnum('ErrorCode');
        if (ErrorCode) {
            this.ErrorCode = ErrorCode.values;
            console.log('Loaded ErrorCode enum:', this.ErrorCode);
        } else {
            console.warn('ErrorCode enum not found in common package');
        }

        // 加载背包类型枚举
        const BagType = common.lookupEnum('BagType');
        if (BagType) {
            this.BagType = BagType.values;
            console.log('Loaded BagType enum:', this.BagType);
        } else {
            console.warn('BagType enum not found in common package');
            // 设置默认值
            this.BagType = {
                BAG_TYPE_NONE: 0,
                BAG_TYPE_MAIN: 1,
            };
            console.log('Using default BagType enum:', this.BagType);
        }
    }

    // 获取枚举名称
    getEnumName(enumType, value) {
        let enumValues;
        switch (enumType) {
            case 'MessageID':
                enumValues = this.MessageID;
                break;
            case 'ErrorCode':
                enumValues = this.ErrorCode;
                break;
            case 'BagType':
                enumValues = this.BagType;
                break;
            default:
                throw new Error(`Unknown enum type: ${enumType}`);
        }

        // 查找枚举值对应的名称
        for (const [name, val] of Object.entries(enumValues)) {
            if (val === value) {
                return name;
            }
        }

        // 如果没找到，返回数字值
        return value.toString();
    }

    // 获取错误码名称
    getErrorCodeName(errorCode) {
        return this.getEnumName('ErrorCode', errorCode);
    }

    // 获取消息ID名称
    getMessageIDName(messageId) {
        return this.getEnumName('MessageID', messageId);
    }

    // 获取背包类型名称
    getBagTypeName(bagType) {
        return this.getEnumName('BagType', bagType);
    }
}

module.exports = ProtoHelper; 