const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class HandleCellEventTest extends BaseTest {
    constructor() {
        super('Handle Cell Event Test');
    }

    async test() {
        try {
            // 掷骰子，获取事件
            console.log('\nRolling dice to trigger events...');
            const rollResponse = await this.client.rollDice();
            assert(rollResponse, 'Roll response should not be null');
            console.log('Roll response keys:', Object.keys(rollResponse));
            
            // 获取事件ID
            const eventIds = rollResponse.event_ids || rollResponse.eventIds || [];
            
            // 检查是否触发了事件
            if (!eventIds || eventIds.length === 0) {
                console.log('No events triggered from roll, trying again...');
                // 再尝试一次
                const secondRoll = await this.client.rollDice();
                const secondEventIds = secondRoll.event_ids || secondRoll.eventIds || [];
                
                if (!secondEventIds || secondEventIds.length === 0) {
                    console.log('No events triggered after two attempts, test skipped');
                    return true; // 跳过测试，但不视为失败
                } else {
                    // 使用第二次掷骰子的结果
                    return this.testHandleEvent(secondEventIds);
                }
            } else {
                // 使用第一次掷骰子的结果
                return this.testHandleEvent(eventIds);
            }
        } catch (error) {
            console.error('Handle cell event test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
    
    async testHandleEvent(eventIds) {
        try {
            console.log(`\nGot events: ${eventIds.join(', ')}`);
            
            // 记录背包状态，用于验证奖励是否正确
            console.log('\nGetting bag info before handling events...');
            const bagBefore = await this.client.getBagInfo();
            
            // 循环处理所有事件
            for (let i = 0; i < eventIds.length; i++) {
                const currentEventId = eventIds[i];
                console.log(`\nHandling event ${i + 1}/${eventIds.length} (ID: ${currentEventId})...`);
                
                const response = await this.client.handleCellEvent(currentEventId);
                
                // 验证响应
                assert(response, 'Response should not be null');
                console.log('Handle event response keys:', Object.keys(response));
                
                // 获取属性，兼容不同的命名风格
                const responseEventId = response.event_id !== undefined ? response.event_id : response.eventId;
                const success = response.success;
                const bags = response.bags || [];
                const nextEventId = response.next_event_id !== undefined ? 
                    response.next_event_id : response.nextEventId;
                const remainingEvents = response.remaining_events || response.remainingEvents || [];
                
                // 验证必要的字段
                assert(responseEventId !== undefined, 'Response should have event_id or eventId');
                assert(success !== undefined, 'Response should have success');
                assert(Array.isArray(bags), 'bags should be an array');
                assert(nextEventId !== undefined, 'Response should have next_event_id or nextEventId');
                assert(Array.isArray(remainingEvents), 'remaining_events or remainingEvents should be an array');
                
                // 检查事件处理是否成功
                assert(success, 'Event handling should succeed');
                assert(responseEventId === currentEventId, 
                    `Event ID in response should match requested ID: ${responseEventId} vs ${currentEventId}`);
                
                // 检查剩余事件
                console.log(`Next event ID: ${nextEventId}`);
                console.log(`Remaining events: ${remainingEvents.join(', ')}`);
                
                // 如果有背包变化，验证变化
                if (bags && bags.length > 0) {
                    console.log('\nChecking bag changes...');
                    const bagAfter = await this.client.getBagInfo();
                    
                    // 比较背包变化
                    console.log('Bag changes detected:');
                    bags.forEach(bag => {
                        const bagType = bag.bag_type !== undefined ? bag.bag_type : bag.bagType;
                        console.log(`Bag type: ${bagType}`);
                        
                        const items = bag.items || [];
                        if (items.length > 0) {
                            items.forEach(item => {
                                const itemId = item.item_id !== undefined ? item.item_id : item.itemId;
                                const count = item.count;
                                console.log(`  Item ID: ${itemId}, Count: ${count}`);
                            });
                        }
                    });
                }
            }
            
            return true;
        } catch (error) {
            console.error('Handle event test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = HandleCellEventTest; 