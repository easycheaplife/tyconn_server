const { program } = require('commander');
const loginBenchmark = require('./login_benchmark');
const bagBenchmark = require('./bag_benchmark');
const heartbeatBenchmark = require('./heartbeat_benchmark');
const useItemBenchmark = require('./use_item_benchmark');

const benchmarks = {
    login: loginBenchmark,
    bag: bagBenchmark,
    heartbeat: heartbeatBenchmark,
    useItem: useItemBenchmark
};

program
    .name('benchmark')
    .description('Game server benchmark tool')
    .version('1.0.0');

program
    .command('run <name>')
    .description('Run a benchmark test')
    .option('-c, --concurrent <number>', 'concurrent users', parseInt)
    .option('-n, --total <number>', 'total requests', parseInt)
    .option('-t, --timeout <number>', 'request timeout (ms)', parseInt)
    .option('-s, --server <host>', 'server host')
    .option('-p, --port <number>', 'server port', parseInt)
    .option('--account <string>', 'test account')
    .option('--password <string>', 'test password')
    .action(async (name, options) => {
        if (!benchmarks[name]) {
            console.error(`Unknown benchmark: ${name}`);
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
            console.log(`Running ${name} benchmark...`);
            await benchmarks[name](options);
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

program.parse(); 