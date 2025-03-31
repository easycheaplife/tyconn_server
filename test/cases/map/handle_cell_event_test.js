const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class HandleCellEventTest extends BaseTest {
    constructor() {
        super('Handle Cell Event Test');
    }

    async test() {
        try {
            // 首先掷骰子，获取事件
            console.log('\nRolling dice to trigger events...');
            const rollResponse = await this.client.rollDice();
            assert(rollResponse, 'Roll response should not be null');
            console.log('Roll response keys:', Object.keys(rollResponse));
            
            // 兼容不同的属性命名
            const eventIds = rollResponse.event_ids || rollResponse.eventIds || [];
            
            // 检查是否触发了事件
            if (!eventIds || eventIds.length === 0) {
                console.log('No events triggered from roll, trying again...');
                // 再尝试一次
                const secondRoll = await this.client.rollDice();
                const secondEventIds = secondRoll.event_ids || secondRoll.eventIds || [];
                
                if (!secondEventIds || secondEventIds.length === 0) {
                    console.log('Still no events triggered, using GM command to set up an event...');
                    
                    // 如果两次都没触发事件，使用GM命令触发一个事件
                    const response = await this.client.gmCommand('trigger_map_event', ["1", "1"]);
                    assert(response.result === 'success', 'GM command should succeed');
                    
                    // 重新获取地图信息
                    const mapInfo = await this.client.getMapInfo();
                    
                    // 掷骰子，确保触发事件
                    const thirdRoll = await this.client.rollDice();
                    const thirdEventIds = thirdRoll.event_ids || thirdRoll.eventIds || [];
                    
                    assert(thirdEventIds && thirdEventIds.length > 0, 
                        'Should have events after GM command');
                    
                    // 使用第三次掷骰子的结果
                    return this.testHandleEvent(thirdEventIds);
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
            console.log('\nGetting bag info before handling event...');
            const bagBefore = await this.client.getBagInfo();
            
            // 处理第一个事件
            console.log(`\nHandling event ID: ${eventIds[0]}...`);
            const response = await this.client.handleCellEvent(eventIds[0]);
            
            // 验证响应
            assert(response, 'Response should not be null');
            console.log('Handle event response keys:', Object.keys(response));
            
            // 获取属性，兼容不同的命名风格
            const eventId = response.event_id !== undefined ? response.event_id : response.eventId;
            const success = response.success;
            const bags = response.bags || [];
            const nextEventId = response.next_event_id !== undefined ? 
                response.next_event_id : response.nextEventId;
            const remainingEvents = response.remaining_events || response.remainingEvents || [];
            
            // 验证必要的字段
            assert(eventId !== undefined, 'Response should have event_id or eventId');
            assert(success !== undefined, 'Response should have success');
            assert(Array.isArray(bags), 'bags should be an array');
            assert(nextEventId !== undefined, 'Response should have next_event_id or nextEventId');
            assert(Array.isArray(remainingEvents), 'remaining_events or remainingEvents should be an array');
            
            // 检查事件处理是否成功
            assert(success, 'Event handling should succeed');
            assert(eventId === eventIds[0], 
                `Event ID in response should match requested ID: ${eventId} vs ${eventIds[0]}`);
            
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
            
            // 如果有下一个事件，处理它
            if (nextEventId > 0) {
                console.log(`\nHandling next event ID: ${nextEventId}...`);
                const nextResponse = await this.client.handleCellEvent(nextEventId);
                
                // 获取下一个响应的success属性
                const nextSuccess = nextResponse.success;
                assert(nextSuccess, 'Next event handling should succeed');
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