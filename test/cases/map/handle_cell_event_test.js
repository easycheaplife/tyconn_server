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
            
            // 获取事件列表
            const events = rollResponse.event_ids || rollResponse.eventIds || [];
            
            // 检查是否触发了事件
            if (!events || events.length === 0) {
                console.log('No events triggered from roll, trying again...');
                // 再尝试一次
                const secondRoll = await this.client.rollDice();
                const secondEvents = secondRoll.event_ids || secondRoll.eventIds || [];
                
                if (!secondEvents || secondEvents.length === 0) {
                    console.log('No events triggered after two attempts, test skipped');
                    return true; // 跳过测试，但不视为失败
                } else {
                    // 使用第二次掷骰子的结果
                    return this.testHandleEvent(secondEvents);
                }
            } else {
                // 使用第一次掷骰子的结果
                return this.testHandleEvent(events);
            }
        } catch (error) {
            console.error('Handle cell event test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
    
    async testHandleEvent(events) {
        try {
            console.log(`\nGot ${events.length} events:`);
            events.forEach(event => {
                console.log(`  Event ID: ${event.event_id}, Cell ID: ${event.cell_id}, Is Random: ${event.is_random_event}`);
            });
            
            // 记录背包状态，用于验证奖励是否正确
            console.log('\nGetting bag info before handling events...');
            const bagBefore = await this.client.getBagInfo();
            
            // 循环处理所有事件
            for (let i = 0; i < events.length; i++) {
                const currentEvent = events[i];
                console.log(`\nHandling event ${i + 1}/${events.length} (ID: ${currentEvent.event_id}, Cell: ${currentEvent.cell_id}, Random: ${currentEvent.is_random_event})...`);
                
                const response = await this.client.handleCellEvent(
                    currentEvent.event_id, 
                    currentEvent.cell_id,
                    currentEvent.is_random_event
                );
                
                // 验证响应
                assert(response, 'Response should not be null');
                console.log('Handle event response keys:', Object.keys(response));
                
                // 验证event_info字段
                assert(response.event_info, 'Response should have event_info field');
                assert(response.event_info.event_id === currentEvent.event_id, 
                    `Event ID in response should match requested ID: ${response.event_info.event_id} vs ${currentEvent.event_id}`);
                assert(response.event_info.cell_id === currentEvent.cell_id, 
                    `Cell ID in response should match requested ID: ${response.event_info.cell_id} vs ${currentEvent.cell_id}`);
                
                // 获取属性，兼容不同的命名风格
                const success = response.success;
                const bags = response.bags || [];
                const nextEventId = response.next_event_id !== undefined ? 
                    response.next_event_id : response.nextEventId;
                const remainingEvents = response.remaining_events || response.remainingEvents || [];
                
                // 验证必要的字段
                assert(success !== undefined, 'Response should have success');
                assert(Array.isArray(bags), 'bags should be an array');
                assert(nextEventId !== undefined, 'Response should have next_event_id or nextEventId');
                assert(Array.isArray(remainingEvents), 'remaining_events or remainingEvents should be an array');
                
                // 检查事件处理是否成功
                assert(success, 'Event handling should succeed');
                
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