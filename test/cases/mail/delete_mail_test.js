const BaseTest = require('../../lib/base_test');
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

            // 找一封未读邮件
            const mailToDelete = listResponse.mails[0];
            assert(mailToDelete, 'Should have at least one mail to test');
            
            console.log(`Selected mail for deletion: ID=${mailToDelete.id}, Status=${mailToDelete.status}`);

            // 先读取邮件
            console.log('\nReading mail before deletion...');
            const readResponse = await this.client.readMail(mailToDelete.id);
            assert(readResponse, 'Read mail response should not be null');
            assert.strictEqual(readResponse.mail_id.low, mailToDelete.id.low, 'Read mail ID should match');

            // 等待一小段时间确保状态更新
            await new Promise(resolve => setTimeout(resolve, 200));

            // 测试删除邮件
            console.log('\nTesting delete mail...');
            const deleteResponse = await this.client.deleteMail(mailToDelete.id);
            
            // 验证响应
            assert(deleteResponse, 'Delete mail response should not be null');
            assert.strictEqual(deleteResponse.mail_id.low, mailToDelete.id.low, 'Deleted mail ID should match');

            // 等待更长时间确保删除完成
            console.log('Waiting for server to process deletion...');
            await new Promise(resolve => setTimeout(resolve, 500));

            // 验证邮件是否已被删除或标记为已删除
            const newListResponse = await this.client.getMailList();
            
            // 打印所有邮件ID和状态（用于调试）
            console.log('\nMail list after deletion:');
            newListResponse.mails.forEach(mail => {
                console.log(`Mail ID: ${mail.id}, Status: ${mail.status}`);
            });
            
            // 查找相同ID的邮件
            const foundMail = newListResponse.mails.find(m => 
                m.id && mailToDelete.id && m.id.low === mailToDelete.id.low);
                
            if (foundMail) {
                console.log(`Found mail after deletion: ID=${foundMail.id}, Status=${foundMail.status}`);
                
                // 检查邮件状态是否为已删除 (status=4)
                if (foundMail.status === 4) {
                    console.log('Mail has been marked as deleted with status=4, test passed');
                    return true;
                } else {
                    assert(false, `Mail found but not marked as deleted. Status: ${foundMail.status}`);
                }
            } else {
                // 邮件已完全从列表中删除
                console.log('Mail completely removed from list, test passed');
                return true;
            }

            return true;
        } catch (error) {
            console.error('Delete mail test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = DeleteMailTest;