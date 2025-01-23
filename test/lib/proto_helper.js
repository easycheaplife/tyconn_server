const protobuf = require('protobufjs');
const path = require('path');
const fs = require('fs');

class ProtoHelper {
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
}

module.exports = ProtoHelper; 