const program = require('commander');
const loginBenchmark = require('./login_benchmark');
const heartbeatBenchmark = require('./heartbeat_benchmark');
const bagBenchmark = require('./bag_benchmark');
const useItemBenchmark = require('./use_item_benchmark');
const stackItemBenchmark = require('./stack_item_benchmark');

program
    .name('benchmark')
    .description('Game server benchmark tool')
    .version('1.0.0');

program
    .command('run <benchmark>')
    .description('Run a benchmark test')
    .option('-c, --concurrent <number>', 'Number of concurrent requests', parseInt)
    .option('-n, --total <number>', 'Total number of requests', parseInt)
    .option('-t, --timeout <number>', 'Request timeout in milliseconds', parseInt)
    .option('-s, --server <host>', 'server host')
    .option('-p, --port <number>', 'server port', parseInt)
    .option('--account <string>', 'test account')
    .option('--password <string>', 'test password')
    .action(async (benchmark, options) => {
        const benchmarks = {
            login: loginBenchmark,
            heartbeat: heartbeatBenchmark,
            bag: bagBenchmark,
            useItem: useItemBenchmark,
            stackItem: stackItemBenchmark  // 添加新的堆叠测试
        };

        if (!benchmarks[benchmark]) {
            console.error(`Unknown benchmark: ${benchmark}`);
            console.log('Available benchmarks:');
            Object.keys(benchmarks).forEach(name => {
                console.log(`  - ${name}`);
            });
            process.exit(1);
        }

        // 更新配置
        if (options.server) process.env.SERVER_HOST = options.server;
        if (options.port) process.env.WS_PORT = options.port;
        if (options.account) process.env.TEST_ACCOUNT = options.account;
        if (options.password) process.env.TEST_PASSWORD = options.password;

        try {
            console.log(`Running ${benchmark} benchmark...`);
            await benchmarks[benchmark](options);
        } catch (error) {
            console.error('Benchmark failed:', error);
            process.exit(1);
        }
    });

program
    .command('list')
    .description('List available benchmarks')
    .action(() => {
        console.log('Available benchmarks:');
        Object.keys(benchmarks).forEach(name => {
            console.log(`  - ${name}`);
        });
    });

program.parse(process.argv); 