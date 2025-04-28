const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class ReadMailTest extends BaseTest {
    constructor() {
        super('Read Mail Test');
    }

    async test() {
        try {
            // 获取用户信息
            console.log('\nGetting user info...');
            const userResponse = await this.client.getUserInfo();
            console.log('Got user info, user ID:', userResponse.user.user_id);

            // 获取初始邮件列表
            console.log('\nGetting initial mail list...');
            const initialMailListResponse = await this.client.getMailList();
            assert(initialMailListResponse && initialMailListResponse.hasOwnProperty('mails'), 
                'Initial response should have a "mails" field');
            
            const initialMailCount = initialMailListResponse.mails ? initialMailListResponse.mails.length : 0;
            console.log(`Initial mail count: ${initialMailCount}`);

            // 如果没有未读邮件，发送一封测试邮件
            let testMailId = null;
            let hasUnreadMail = false;
            
            if (initialMailCount > 0) {
                // 检查是否有未读邮件
                const unreadMail = initialMailListResponse.mails.find(mail => mail.status === 0);
                if (unreadMail) {
                    testMailId = unreadMail.id && (typeof unreadMail.id === 'object') ? 
                        (unreadMail.id.low || unreadMail.id.toString()) : unreadMail.id;
                    console.log(`\nFound unread mail with ID: ${testMailId}`);
                    console.log(`- Title: ${unreadMail.title}`);
                    console.log(`- Status: ${unreadMail.status}`);
                    hasUnreadMail = true;
                }
            }
            
            // 如果没有未读邮件，发送一封测试邮件
            if (!hasUnreadMail) {
                console.log('\nNo unread mails found. Sending a test mail...');
                const mailTitle = '未读测试邮件_' + Date.now();
                const mailContent = '这是一封用于测试阅读功能的邮件';

                console.log(`Sending mail with title: "${mailTitle}"`);
                const sendMailResponse = await this.client.gmCommand('send_mail', [
                    String(userResponse.user.user_id),
                    mailTitle,
                    mailContent,
                    '0',
                    '0',
                    '0',
                    '0'
                ]);
                
                console.log('Send mail response:', JSON.stringify(sendMailResponse));
                
                // 验证响应
                const responseStr = JSON.stringify(sendMailResponse);
                const containsMailTitle = responseStr.includes(mailTitle);
                assert(containsMailTitle, `Failed to send test mail: response does not contain expected mail title`);
                
                // 等待邮件处理完成
                console.log('\nWaiting for mail to be processed...');
                await new Promise(resolve => setTimeout(resolve, 1000));

                // 重新获取邮件列表
                console.log('\nGetting updated mail list...');
                const updatedMailListResponse = await this.client.getMailList();
                assert(updatedMailListResponse && updatedMailListResponse.hasOwnProperty('mails') && updatedMailListResponse.mails, 
                    'Updated response should have a non-empty "mails" field');
                
                // 查找新发送的邮件
                let found = false;
                for (const mail of updatedMailListResponse.mails) {
                    if (mail.title === mailTitle) {
                        testMailId = mail.id && (typeof mail.id === 'object') ? 
                            (mail.id.low || mail.id.toString()) : mail.id;
                            
                        console.log(`Found test mail with ID: ${testMailId}`);
                        console.log(`- Title: ${mail.title}`);
                        console.log(`- Status: ${mail.status}`);
                        found = true;
                        hasUnreadMail = true;
                        break;
                    }
                }
                
                assert(found, `Could not find the test mail with title "${mailTitle}" in the mail list`);
            }

            // 如果没有找到任何邮件，使用第一封邮件进行测试
            if (!hasUnreadMail && initialMailCount > 0) {
                const firstMail = initialMailListResponse.mails[0];
                testMailId = firstMail.id && (typeof firstMail.id === 'object') ? 
                    (firstMail.id.low || firstMail.id.toString()) : firstMail.id;
                    
                console.log(`\nNo unread mail found. Using first available mail - ID: ${testMailId}`);
                console.log(`- Title: ${firstMail.title}`);
                console.log(`- Status: ${firstMail.status}`);
            }
            
            // 确保有邮件可以阅读
            assert(testMailId, 'Could not find any mail to test');
            
            // 执行阅读操作
            console.log(`\nReading mail with ID: ${testMailId}...`);
            const readResponse = await this.client.readMail(testMailId);
            console.log('Read mail response:', JSON.stringify(readResponse));
            
            // 验证响应
            assert(readResponse && readResponse.success !== false, 
                `Read mail response should indicate success, got: ${JSON.stringify(readResponse)}`);
            
            // 等待阅读操作处理完成
            console.log('\nWaiting for read operation to be processed...');
            await new Promise(resolve => setTimeout(resolve, 1000));

            // 获取更新后的邮件列表
            console.log('\nGetting mail list after reading...');
            const finalMailListResponse = await this.client.getMailList();
            assert(finalMailListResponse && finalMailListResponse.hasOwnProperty('mails'), 
                'Final response should have a "mails" field');
            
            // 查找读取的邮件，验证状态已更新
            let found = false;
            console.log('\nVerifying mail was read:');
            
            if (finalMailListResponse.mails && finalMailListResponse.mails.length > 0) {
                for (const mail of finalMailListResponse.mails) {
                    const mailId = mail.id && (typeof mail.id === 'object') ? 
                        (mail.id.low || mail.id.toString()) : mail.id;
                        
                    if (mailId == testMailId) {
                        console.log(`- Found mail with ID: ${mailId}`);
                        console.log(`- Title: ${mail.title}`);
                        console.log(`- Status: ${mail.status}`);
                        found = true;
                        
                        // 验证状态为已读 (1)
                        assert(mail.status === 1, `Mail should be marked as read (status=1) but has status ${mail.status}`);
                        break;
                    }
                }
            }
            
            if (!found) {
                console.log(`WARNING: Could not find mail with ID ${testMailId} after reading`);
            } else {
                console.log('Mail was successfully marked as read');
            }
            
            console.log('\nRead mail test completed successfully');
            return true;
        } catch (error) {
            console.error('Read mail test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ReadMailTest; 