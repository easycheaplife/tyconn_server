const BaseTest = require('../lib/base_test');
const assert = require('assert');

class ReadMailTest extends BaseTest {
    constructor() {
        super('Read Mail Test');
    }

    async test() {
        try {
            // 先获取邮件列表
            console.log('\nGetting mail list for read test...');
            const listResponse = await this.client.getMailList();
            assert(listResponse.mails && listResponse.mails.length > 0, 'Should have mails to test');

            // 找一封未读邮件
            const unreadMail = listResponse.mails.find(mail => mail.status === 1); // MAIL_STATUS_UNREAD
            if (!unreadMail) {
                console.log('No unread mail to test');
                return true;
            }

            // 测试读取邮件
            console.log('\nTesting read mail...');
            const readResponse = await this.client.readMail(unreadMail.id);
            
            // 验证响应
            assert(readResponse, 'Read mail response should not be null');
            assert.strictEqual(readResponse.mail_id.low, unreadMail.id.low, 'Read mail ID should match');

            // 验证邮件状态更新
            const newListResponse = await this.client.getMailList();
            const updatedMail = newListResponse.mails.find(m => m.id.low === unreadMail.id.low);
            assert.strictEqual(updatedMail.status, 2, 'Mail status should be updated to READ');

            return true;
        } catch (error) {
            console.error('Read mail test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ReadMailTest; 