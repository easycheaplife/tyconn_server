const yargs = require('yargs');

function parseArgs() {
    return yargs
        .option('test', {
            alias: 't',
            description: '要运行的测试用例名称',
            type: 'string'
        })
        .option('server', {
            alias: 's',
            description: '服务器地址',
            type: 'string'
        })
        .option('port', {
            alias: 'p',
            description: '服务器端口',
            type: 'number'
        })
        .option('token', {
            description: '使用指定的token（跳过登录）',
            type: 'string'
        })
        .help()
        .argv;
}

module.exports = {
    parseArgs
}; 