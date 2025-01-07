// client.js
const WebSocket = require('ws');
const readline = require('readline');

// 创建 readline 接口
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// 创建 WebSocket 客户端连接到服务器
const socket = new WebSocket('ws://localhost:8891');

// 连接打开时触发
socket.on('open', () => {
    console.log('Connected to the server');
    console.log('Available commands:');
    console.log('hello|<name> - Send hello message');
    console.log('echo|<message> - Echo message');
    console.log('quit - Close connection');
    
    // 启动消息输入循环
    promptMessage();
});

// 接收到服务器的消息时触发
socket.on('message', (data) => {
    console.log('\nReceived from server:', data.toString());
    promptMessage();
});

// 连接关闭时触发
socket.on('close', () => {
    console.log('Disconnected from the server');
    rl.close();
    process.exit(0);
});

// 错误处理
socket.on('error', (error) => {
    console.error('WebSocket Error:', error);
    rl.close();
    process.exit(1);
});

// 提示用户输入消息
function promptMessage() {
    rl.question('Enter message (hello|name or echo|message): ', (input) => {
        if (input.toLowerCase() === 'quit') {
            console.log('Closing connection...');
            socket.close();
            return;
        }

        // 检查消息格式
        if (!input.includes('|')) {
            console.log('Invalid format. Use: command|message');
            promptMessage();
            return;
        }

        // 发送消息到服务器
        socket.send(input);
    });
}

// 处理程序退出
process.on('SIGINT', () => {
    console.log('\nClosing connection...');
    socket.close();
    rl.close();
    process.exit(0);
});
