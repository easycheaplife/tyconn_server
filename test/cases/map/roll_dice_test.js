const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class RollDiceTest extends BaseTest {
    constructor() {
        super('Roll Dice Test');
    }

    async test() {
        try {
            // 首先获取当前地图信息，用于后面验证
            console.log('\nGetting current map info...');
            const mapInfo = await this.client.getMapInfo();
            assert(mapInfo, 'Map info should not be null');
            
            // 获取属性，兼容不同的命名风格
            const currentPosition = mapInfo.current_position !== undefined ? 
                mapInfo.current_position : mapInfo.currentPosition;
            const direction = mapInfo.direction;
            
            console.log(`Current position: ${currentPosition}, Direction: ${direction}`);
            
            // 测试: 掷骰子
            console.log('\nTesting roll dice...');
            const response = await this.client.rollDice();
            
            // 验证响应
            assert(response, 'Response should not be null');
            console.log('Roll dice response keys:', Object.keys(response));
            
            // 验证字段 - 考虑不同的属性命名可能性
            assert(response.hasOwnProperty('dice_value') || response.hasOwnProperty('diceValue'), 
                'Response should have dice_value or diceValue');
            assert(response.from_position !== undefined || response.fromPosition !== undefined, 
                'Response should have from_position or fromPosition');
            assert(response.hasOwnProperty('to_position') || response.hasOwnProperty('toPosition'), 
                'Response should have to_position or toPosition');
            assert(Array.isArray(response.event_ids) || Array.isArray(response.eventIds), 
                'event_ids or eventIds should be an array');
            
            // 获取数据，兼容不同的命名风格
            const diceValue = response.dice_value !== undefined ? response.dice_value : response.diceValue;
            const fromPosition = response.from_position !== undefined ? response.from_position : response.fromPosition;
            const toPosition = response.to_position !== undefined ? response.to_position : response.toPosition;
            const eventIds = response.event_ids || response.eventIds || [];
            
            // 检查值范围和逻辑
            assert(diceValue >= 1 && diceValue <= 6, 
                `Dice value should be between 1 and 6, got ${diceValue}`);
            assert(fromPosition === currentPosition, 
                `From position should match current position, got ${fromPosition} vs ${currentPosition}`);
            
            // 检查新位置是否合理（基于原位置、骰子点数和方向）
            const expectedPosition = (currentPosition + 
                (direction * diceValue)) % 30; // 假设地图有30个格子
            
            // 由于可能有特殊格子效果，我们不能确切判断to_position，但可以记录结果
            console.log(`Rolled ${diceValue}, moved from ${fromPosition} to ${toPosition}`);
            console.log(`Direction: ${direction}, Expected position: ${expectedPosition}`);
            
            if (eventIds.length > 0) {
                console.log(`Triggered events: ${eventIds.join(', ')}`);
            } else {
                console.log('No events triggered');
            }
            
            // 检查地图状态是否更新
            const updatedMapInfo = await this.client.getMapInfo();
            const updatedPosition = updatedMapInfo.current_position !== undefined ? 
                updatedMapInfo.current_position : updatedMapInfo.currentPosition;
                
            assert(updatedPosition === toPosition, 
                `Updated position should match to_position, got ${updatedPosition} vs ${toPosition}`);
            
            // 如果有事件，验证处理事件的逻辑
            if (eventIds.length > 0) {
                console.log('\nTesting handle first event...');
                const eventResponse = await this.client.handleCellEvent(eventIds[0]);
                assert(eventResponse, 'Event response should not be null');
                
                const responseEventId = eventResponse.event_id !== undefined ? 
                    eventResponse.event_id : eventResponse.eventId;
                    
                assert(responseEventId === eventIds[0], 
                    'Event ID in response should match requested event ID');
            }
            
            return true;
        } catch (error) {
            console.error('Roll dice test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = RollDiceTest; 