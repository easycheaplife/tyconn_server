const BaseTest = require('../lib/base_test');
const assert = require('assert');

class DeleteMailTest extends BaseTest {
    constructor() {
        super('Delete Mail Test');
    }

    async test() {
        try {
            let response = await this.client.getUserInfo();
            // 发送个人邮件 
            console.log('\nTesting send personal mail...');
            const personalMailResponse = await this.client.gmCommand(
                'send_mail',
                [String(response.user.user_id), '个人邮件测试', '这是一封测试邮件', '1001', '1000', '2001', '5']
            );
            assert(personalMailResponse, "No response received for personal mail");
            assert(personalMailResponse.result === "success", 
                `Failed to send personal mail: ${personalMailResponse.message}`);   

            // 先获取邮件列表
            console.log('\nGetting mail list for delete test...');
            const listResponse = await this.client.getMailList();
            assert(listResponse.mails && listResponse.mails.length > 0, 'Should have mails to test');

            // 找一封已读或已领取的邮件
            const mailToDelete = listResponse.mails.find(mail => 
                mail.status === 2 || // READ
                mail.status === 3    // CLAIMED
            );

            if (!mailToDelete) {
                console.log('No mail available for delete test');
                return true;
            }

            // 测试删除邮件
            console.log('\nTesting delete mail...');
            const deleteResponse = await this.client.deleteMail(mailToDelete.id);
            
            // 验证响应
            assert(deleteResponse, 'Delete mail response should not be null');
            assert.strictEqual(deleteResponse.mail_id.low, mailToDelete.id.low, 'Deleted mail ID should match');

            // 验证邮件是否已被删除
            const newListResponse = await this.client.getMailList();
            const deletedMail = newListResponse.mails.find(m => m.id.low === mailToDelete.id.low);
            assert(!deletedMail, 'Mail should be deleted from list');

            return true;
        } catch (error) {
            console.error('Delete mail test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = DeleteMailTest; 