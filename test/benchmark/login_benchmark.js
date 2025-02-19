const Benchmark = require('../lib/benchmark');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

async function loginBenchmark(options = {}) {
    const benchmark = new Benchmark({
        concurrent: options.concurrent || 100,
        total: options.total || 1000,
        timeout: options.timeout || 5000
    });

    const report = await benchmark.run(async () => {
        const client = new LoginClient();
        // 使用随机账号避免冲突
        const account = `test_${Math.random().toString(36).slice(2)}`;
        await client.login(account, config.testPassword);
    });

    // 打印报告
    console.log('\nLogin Benchmark Results:');
    console.log('-'.repeat(50));
    console.log(`Total Requests: ${report.total}`);
    console.log(`Success: ${report.success}`);
    console.log(`Failed: ${report.failed}`);
    console.log(`Success Rate: ${report.successRate}%`);
    console.log(`Average Time: ${report.avgTime}ms`);
    console.log(`QPS: ${report.qps}`);
    console.log(`P95: ${report.p95}ms`);
    console.log(`P99: ${report.p99}ms`);
    console.log(`Duration: ${(report.duration/1000).toFixed(1)}s`);

    if (Object.keys(report.errors).length > 0) {
        console.log('\nError Distribution:');
        for (const [code, count] of Object.entries(report.errors)) {
            console.log(`- ${code}: ${count}`);
        }
    }
}

module.exports = loginBenchmark; 