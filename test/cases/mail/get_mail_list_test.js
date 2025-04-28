const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class GetMailListTest extends BaseTest {
    constructor() {
        super('Get Mail List Test');
    }

    async test() {
        try {
            console.log('\nTesting get mail list...');
            let response = await this.client.getMailList();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.mails), 'Mails should be an array');
            
            // 验证欢迎邮件
            const welcomeMail = response.mails.find(mail => 
                mail.title === "欢迎来到游戏" && 
                mail.mail_type === 1  // MAIL_TYPE_SYSTEM
            );
            
            if (welcomeMail) {
                // 验证欢迎邮件字段
                const requiredFields = ['id', 'title', 'content', 'mail_type', 'status', 'create_time', 'expire_time'];
                for (const field of requiredFields) {
                    assert(field in welcomeMail, `Missing required field in welcome mail: ${field}`);
                }

                // 验证欢迎邮件物品
                assert(welcomeMail.items && welcomeMail.items.length > 0, 'Welcome mail should have items');
                const goldItem = welcomeMail.items.find(item => item.item_id === 1001);
                assert(goldItem && goldItem.count === 10000, 'Welcome mail should have 10000 gold');
                
                const expItem = welcomeMail.items.find(item => item.item_id === 2001);
                assert(expItem && expItem.count === 5, 'Welcome mail should have 5 exp potions');
            }

            return true;
        } catch (error) {
            console.error('Get mail list test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = GetMailListTest; 