const cluster = require('cluster');
const numCPUs = require('os').cpus().length;
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

// 命令行参数配置
const argv = yargs(hideBin(process.argv))
    .option('connections', {
        alias: 'c',
        type: 'number',
        description: '总连接数',
        default: 1000
    })
    .option('concurrent', {
        alias: 'n',
        type: 'number',
        description: '并发连接数',
        default: 100
    })
    .option('duration', {
        alias: 'd',
        type: 'number',
        description: '压测持续时间(秒)',
        default: 300
    })
    .option('host', {
        alias: 'h',
        type: 'string',
        description: '服务器地址',
        default: 'localhost'
    })
    .option('port', {
        alias: 'p',
        type: 'number',
        description: '服务器端口',
        default: 8008
    })
    .help()
    .argv;

// 基础配置
const CONFIG = {
    connections: argv.connections,
    concurrent: argv.concurrent,
    interval: 100,
    messageInterval: 1000,
    duration: argv.duration,
    host: argv.host,
    port: argv.port,
    ssl: false,
    keepAlive: true,
    responseTimeout: 5000
};

if (cluster.isMaster) {
    // 主进程代码
    console.log(`Master ${process.pid} is running`);
    console.log('Starting benchmark with config:', CONFIG);
    
    // 启动工作进程
    const workers = [];
    const workerCount = Math.min(numCPUs - 1, 4);
    
    // 统计信息
    const masterStats = {
        connected: 0,
        failed: 0,
        messages: {
            sent: 0,
            received: 0,
            failed: 0
        },
        responses: {
            success: 0,
            error: 0,
            timeout: 0
        }
    };
    
    // 启动工作进程
    for (let i = 0; i < workerCount; i++) {
        const worker = cluster.fork({
            WORKER_ID: i,
            WORKER_COUNT: workerCount,
            CONNECTIONS: Math.floor(CONFIG.connections / workerCount),
            HOST: CONFIG.host,
            PORT: CONFIG.port,
            DURATION: CONFIG.duration,
            MESSAGE_INTERVAL: CONFIG.messageInterval
        });
        workers.push(worker);
        
        worker.on('message', (msg) => {
            if (msg.type === 'stats') {
                // 合并统计信息
                masterStats.connected += msg.stats.connected;
                masterStats.failed += msg.stats.failed;
                masterStats.messages.sent += msg.stats.messages.sent;
                masterStats.messages.received += msg.stats.messages.received;
                masterStats.messages.failed += msg.stats.messages.failed;
                masterStats.responses.success += msg.stats.responses.success;
                masterStats.responses.error += msg.stats.responses.error;
                masterStats.responses.timeout += msg.stats.responses.timeout;
            }
        });
    }
    
    // 定时打印汇总统计信息
    setInterval(() => {
        console.log('\nCombined Stats:');
        console.log('Connections:', masterStats.connected);
        console.log('Failed:', masterStats.failed);
        console.log('Messages Sent:', masterStats.messages.sent);
        console.log('Messages Received:', masterStats.messages.received);
        console.log('Messages Failed:', masterStats.messages.failed);
        console.log('Response Success:', masterStats.responses.success);
        console.log('Response Error:', masterStats.responses.error);
        console.log('Response Timeout:', masterStats.responses.timeout);
    }, 5000);
    
    // 处理进程退出
    process.on('SIGINT', async () => {
        console.log('Master shutting down...');
        // 通知所有工作进程关闭
        for (const worker of workers) {
            worker.send({ type: 'shutdown' });
        }
        // 等待所有工作进程退出
        await Promise.all(workers.map(worker => {
            return new Promise(resolve => {
                worker.on('exit', resolve);
            });
        }));
        process.exit(0);
    });
    
} else {
    // 工作进程代码
    console.log(`Worker ${process.pid} started`);
    
    // 从环境变量获取配置
    const workerId = parseInt(process.env.WORKER_ID);
    const workerCount = parseInt(process.env.WORKER_COUNT);
    const connections = parseInt(process.env.CONNECTIONS);
    
    // 修改配置
    CONFIG.connections = connections;
    CONFIG.host = process.env.HOST;
    CONFIG.port = parseInt(process.env.PORT);
    CONFIG.duration = parseInt(process.env.DURATION);
    CONFIG.messageInterval = parseInt(process.env.MESSAGE_INTERVAL);
    
    // 导入压测脚本
    require('./websocket_bench');
} 

/*
# 使用默认配置
node test/websocket_bench_cluster.js

# 或指定参数
node test/websocket_bench_cluster.js -c 2000 -n 200 -d 300 -h localhost -p 8008
*/
