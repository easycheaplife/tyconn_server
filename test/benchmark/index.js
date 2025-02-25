const loginBenchmark = require('./login_benchmark');
const heartbeatBenchmark = require('./heartbeat_benchmark');
const bagBenchmark = require('./bag_benchmark');
const useItemBenchmark = require('./use_item_benchmark');
const stackItemBenchmark = require('./stack_item_benchmark');

const benchmarks = {
    login: loginBenchmark,
    heartbeat: heartbeatBenchmark,
    bag: bagBenchmark,
    useItem: useItemBenchmark,
    stackItem: stackItemBenchmark
};

async function runBenchmark(name) {
    if (!name) {
        console.error('Please specify a benchmark name');
        console.log('Available benchmarks:');
        Object.keys(benchmarks).forEach(name => {
            console.log(`  - ${name}`);
        });
        process.exit(1);
    }

    const benchmark = benchmarks[name];
    if (!benchmark) {
        console.error(`Unknown benchmark: ${name}`);
        console.log('Available benchmarks:');
        Object.keys(benchmarks).forEach(name => {
            console.log(`  - ${name}`);
        });
        process.exit(1);
    }

    try {
        console.log(`Running ${name} benchmark...`);
        await benchmark();
    } catch (error) {
        console.error('Benchmark failed:', error);
        process.exit(1);
    }
}

// 解析命令行参数
const args = process.argv.slice(2);
const name = args[0];

runBenchmark(name); 