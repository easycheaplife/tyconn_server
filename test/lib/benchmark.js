const LoginClient = require('./login_client');
const GameClient = require('./game_client');
const config = require('../config/config');

class Benchmark {
    constructor(options) {
        this.concurrent = options.concurrent || 100;  // 并发数
        this.total = options.total || 1000;          // 总请求数
        this.timeout = options.timeout || 5000;      // 超时时间
        this.startTime = Date.now();
        this.results = {
            success: 0,
            failed: 0,
            times: [],
            errors: new Map()  // 错误码统计
        };
    }

    async run(fn) {
        console.log('\nStarting benchmark...');
        console.log(`Concurrent: ${this.concurrent}`);
        console.log(`Total: ${this.total}`);
        
        this.startTime = Date.now();
        const batches = Math.ceil(this.total / this.concurrent);
        
        for (let i = 0; i < batches; i++) {
            const count = Math.min(this.concurrent, this.total - i * this.concurrent);
            const promises = Array(count).fill().map(() => this.execute(fn));
            await Promise.all(promises);
            
            // 打印进度
            const progress = ((i + 1) * this.concurrent / this.total * 100).toFixed(1);
            console.log(`Progress: ${progress}% (${(i + 1) * this.concurrent}/${this.total})`);
        }

        return this.getReport();
    }

    async execute(fn) {
        const start = Date.now();
        try {
            await fn();
            this.results.success++;
            this.results.times.push(Date.now() - start);
        } catch (error) {
            this.results.failed++;
            // 统计错误码
            const errorCode = error.response?.errorCode || 'UNKNOWN';
            this.results.errors.set(
                errorCode, 
                (this.results.errors.get(errorCode) || 0) + 1
            );
        }
    }

    getReport() {
        const total = this.results.times.length;
        const avgTime = total > 0 
            ? this.results.times.reduce((a, b) => a + b) / total 
            : 0;
        const sorted = [...this.results.times].sort((a, b) => a - b);
        const duration = Date.now() - this.startTime;
        
        // 错误分布
        const errorDistribution = {};
        for (const [code, count] of this.results.errors) {
            errorDistribution[code] = count;
        }
        
        return {
            total: this.total,
            success: this.results.success,
            failed: this.results.failed,
            successRate: (this.results.success / this.total * 100).toFixed(1),
            avgTime: Math.round(avgTime),
            p95: sorted[Math.floor(total * 0.95)] || 0,
            p99: sorted[Math.floor(total * 0.99)] || 0,
            qps: Math.round(this.results.success * 1000 / duration),
            duration: duration,
            errors: errorDistribution
        };
    }
}

module.exports = Benchmark; 