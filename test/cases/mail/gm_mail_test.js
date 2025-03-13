const BaseTest = require('../../lib/base_test');
const assert = require('assert');

const receive_mail_user_id = '2'
class GmMailTest extends BaseTest {
    constructor() {
        super('GM Mail Test');
    }

    async test() {
        try {
            let response = await this.client.getUserInfo();
            console.log('User info response:', JSON.stringify(response, null, 2));
            
            // 1. 测试发送个人邮件
            console.log('\nTesting send personal mail...');
            const personalMailResponse = await this.client.gmCommand(
                'send_mail',
                [String(response.user.userId || response.user.user_id), '个人邮件测试', '这是一封测试邮件', '1001', '1000', '2001', '5']
            );
            
            assert(personalMailResponse, "No response received for personal mail");
            assert(personalMailResponse.result === "success", 
                `Failed to send personal mail: ${personalMailResponse.message}`);
            
            // 2. 测试发送系统邮件
            console.log('\nTesting send system mail...');
            const systemMailResponse = await this.client.gmCommand(
                'send_system_mail',
                ['系统邮件测试', '这是一封系统邮件', '1001', '2000', '2001', '10']
            );
            
            assert(systemMailResponse, "No response received for system mail");
            assert(systemMailResponse.result === "success", 
                `Failed to send system mail: ${systemMailResponse.message}`);
            
            // 3. 验证邮件是否发送成功
            console.log('\nVerifying mails...');
            const mailListResponse = await this.client.getMailList();
            
            assert(mailListResponse && mailListResponse.mails, "Failed to get mail list");
            
            // 查找个人邮件
            const personalMail = mailListResponse.mails.find(mail => 
                mail.title === '个人邮件测试' && 
                mail.content === '这是一封测试邮件'
            );
            assert(personalMail, "Personal mail not found");
            assert(personalMail.items && personalMail.items.length === 2, "Personal mail should have 2 items");
            assert(personalMail.items[0].item_id === 1001 && personalMail.items[0].count === 1000,
                "First item in personal mail doesn't match");
            assert(personalMail.items[1].item_id === 2001 && personalMail.items[1].count === 5,
                "Second item in personal mail doesn't match");
            /*
            // 查找系统邮件
            const systemMail = mailListResponse.mails.find(mail => 
                mail.title === '系统邮件测试' && 
                mail.content === '这是一封系统邮件'
            );
            assert(systemMail, "System mail not found");
            assert(systemMail.items && systemMail.items.length === 2, "System mail should have 2 items");
            assert(systemMail.items[0].item_id === 1001 && systemMail.items[0].count === 2000,
                "First item in system mail doesn't match");
            assert(systemMail.items[1].item_id === 2001 && systemMail.items[1].count === 10,
                "Second item in system mail doesn't match");
            */
            // 4. 测试错误情况
            console.log('\nTesting error cases...');
            
            // 测试未知命令
            try {
                await this.client.gmCommand(
                    'invalid_command',
                    []
                );
                assert(false, "Should throw error for unknown command");
            } catch (error) {
                assert(error.errorCode === 300, "Should fail with ERROR_CODE_GM_COMMAND_FAILED");
                assert(error.details.errorMsg === "unknown GM command", "Should have correct error message");
            }
            
            // 测试个人邮件参数不足
            try {
                await this.client.gmCommand(
                    'send_mail',
                    [receive_mail_user_id]  // 只提供接收者ID，缺少标题和内容
                );
                assert(false, "Should throw error with insufficient parameters for personal mail");
            } catch (error) {
                assert(error.errorCode === 300, "Should fail with ERROR_CODE_GM_COMMAND_FAILED");
                assert(error.details && error.details.errorCode === 300, "Error details should contain error code");
                assert(error.details.errorName === "ERROR_CODE_GM_COMMAND_FAILED", "Error details should contain error name");
            }
            
            // 测试系统邮件参数不足
            try {
                await this.client.gmCommand(
                    'send_system_mail',
                    ['标题']  // 只提供标题，缺少内容
                );
                assert(false, "Should throw error with insufficient parameters for system mail");
            } catch (error) {
                assert(error.errorCode === 300, "Should fail with ERROR_CODE_GM_COMMAND_FAILED");
                assert(error.details && error.details.errorCode === 300, "Error details should contain error code");
                assert(error.details.errorName === "ERROR_CODE_GM_COMMAND_FAILED", "Error details should contain error name");
            }
            
            return true;
        } catch (error) {
            console.error('GM mail test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = GmMailTest; 