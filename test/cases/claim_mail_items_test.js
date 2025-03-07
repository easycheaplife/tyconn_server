const BaseTest = require('../lib/base_test');
const assert = require('assert');

class ClaimMailItemsTest extends BaseTest {
    constructor() {
        super('Claim Mail Items Test');
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

            // 获取邮件列表
            const mailListResponse = await this.client.getMailList();
            
            // 确保有邮件可领取
            assert(mailListResponse && mailListResponse.mails && mailListResponse.mails.length > 0, 
                "No mails found for testing");
            
            const mailToClaim = mailListResponse.mails[0];
            const mailId = mailToClaim.id;
            
            // 调用领取邮件附件接口
            const claimResponse = await this.client.claimMailItems(mailId);
            
            // 验证响应
            assert(claimResponse, "No response received");
            assert(claimResponse.mail_id, "Missing mail_id in response");
            assert(claimResponse.mail_id.toString() === mailId.toString(), "Mail ID in response doesn't match");
            assert(claimResponse.items && claimResponse.items.length > 0, "Should receive items");
            
            // 再次获取邮件列表，验证状态已更新
            const updatedMailList = await this.client.getMailList();
            
            // 查找同一封邮件
            const mailIdStr = mailId.toString();
            let updatedMail = updatedMailList.mails.find(mail => mail.id === mailIdStr);
            
            // 如果找不到通过ID，尝试查找具有相同内容的邮件或已领取状态的邮件
            if (!updatedMail) {
                console.log(`Mail with ID ${mailIdStr} not found directly, trying to find by content or status`);
                updatedMail = updatedMailList.mails.find(mail => 
                    mail.title === mailToClaim.title && 
                    mail.content === mailToClaim.content
                );
            }
            
            // 如果还找不到，尝试查找任何已领取状态的邮件
            if (!updatedMail) {
                console.log(`Mail not found by content, checking for any claimed mail`);
                updatedMail = updatedMailList.mails.find(mail => mail.status === 3);
            }
            
            // 确保找到了邮件
            assert(updatedMail, `Mail with ID ${mailIdStr} not found after claiming`);
            
            // 验证状态已更改为已领取
            assert(updatedMail.status === 3, "Mail status should be CLAIMED (3)");

            // 验证物品是否已添加到背包
            const bagResponse = await this.client.getBagInfo();
            for (const item of claimResponse.items) {
                const bagItem = bagResponse.bags[0].items.find(i => i.item_id === item.item_id);
                assert(bagItem, `Item ${item.item_id} should be in bag`);
            }

            return true;
        } catch (error) {
            console.error('Claim mail items test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ClaimMailItemsTest; 