const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class GetMapInfoTest extends BaseTest {
    constructor() {
        super('Get Map Info Test');
    }

    async test() {
        try {
            // 测试: 获取地图信息
            console.log('\nTesting get map info...');
            const response = await this.client.getMapInfo();
            
            // 验证响应
            assert(response, 'Response should not be null');
            console.log('Response object keys:', Object.keys(response));
            
            // 验证地图字段 - 考虑不同的属性命名可能性
            // 检查 chapter_id 或 chapterId
            assert(response.hasOwnProperty('chapter_id') || response.hasOwnProperty('chapterId'), 
                'Response should have chapter_id or chapterId');
            
            // 检查 current_position 或 currentPosition
            const currentPosition = response.current_position !== undefined ? response.current_position : 
                                   (response.currentPosition !== undefined ? response.currentPosition : 0);
            
            // 检查 direction
            assert(response.hasOwnProperty('direction'), 
                'Response should have direction');
            
            // 从响应中获取数据，兼容不同的命名风格
            const chapterId = response.chapter_id !== undefined ? response.chapter_id : response.chapterId;
            const direction = response.direction;
            
            // 检查字段类型和范围
            assert(Number.isInteger(chapterId) && chapterId >= 1, 
                'Chapter ID should be a positive integer');
            assert(Number.isInteger(currentPosition) && currentPosition >= 0, 
                'Current position should be a non-negative integer');
            assert([-1, 1].includes(direction), 
                'Direction should be either 1 (forward) or -1 (backward)');
            
            console.log(`Map info: Chapter ${chapterId}, ` + 
                        `Position ${currentPosition}, ` + 
                        `Direction ${direction === 1 ? 'Forward' : 'Backward'}`);
            
            // 检查随机事件数据
            const randomEvents = response.random_events || response.randomEvents;
            if (randomEvents && Array.isArray(randomEvents)) {
                console.log(`Found ${randomEvents.length} random events on the map:`);
                randomEvents.forEach((event, index) => {
                    const eventId = event.event_id !== undefined ? event.event_id : event.eventId;
                    const cellId = event.cell_id !== undefined ? event.cell_id : event.cellId;
                    const isRandomEvent = event.is_random_event !== undefined ? event.is_random_event : event.isRandomEvent;
                    
                    console.log(`  Event #${index + 1}: Event ID=${eventId}, Cell ID=${cellId}, Is Random=${isRandomEvent}`);
                });
            } else {
                console.log('No random events found on the map.');
            }
            
            // 检查事件触发记录
            const eventTriggers = response.event_triggers || response.eventTriggers;
            if (eventTriggers && Array.isArray(eventTriggers)) {
                console.log(`Found ${eventTriggers.length} event trigger records:`);
                eventTriggers.forEach((trigger, index) => {
                    const chapterId = trigger.chapter_id !== undefined ? trigger.chapter_id : trigger.chapterId;
                    const eventId = trigger.event_id !== undefined ? trigger.event_id : trigger.eventId;
                    const triggerCount = trigger.trigger_count !== undefined ? trigger.trigger_count : trigger.triggerCount;
                    
                    console.log(`  Trigger #${index + 1}: Chapter ID=${chapterId}, Event ID=${eventId}, Count=${triggerCount}`);
                });
            } else {
                console.log('No event trigger records found.');
            }
            
            // 测试掷骰子并验证随机事件
            console.log('\nTesting roll dice and check random events...');
            const diceResponse = await this.client.rollDice();
            
            assert(diceResponse, 'Dice response should not be null');
            console.log('Dice response object keys:', Object.keys(diceResponse));
            
            assert(diceResponse.hasOwnProperty('dice_value') || diceResponse.hasOwnProperty('diceValue'), 
                'Dice response should have dice_value');
            
            const diceValue = diceResponse.dice_value !== undefined ? diceResponse.dice_value : diceResponse.diceValue;
            const fromPosition = diceResponse.from_position !== undefined ? diceResponse.from_position : diceResponse.fromPosition;
            const toPosition = diceResponse.to_position !== undefined ? diceResponse.to_position : diceResponse.toPosition;
            
            console.log(`Rolled dice: Value=${diceValue}, From=${fromPosition}, To=${toPosition}`);
            
            // 检查掷骰子后触发的事件
            const eventIds = diceResponse.event_ids || diceResponse.eventIds;
            if (eventIds && Array.isArray(eventIds)) {
                console.log(`Found ${eventIds.length} events triggered by dice roll:`);
                eventIds.forEach((event, index) => {
                    const eventId = event.event_id !== undefined ? event.event_id : event.eventId;
                    const cellId = event.cell_id !== undefined ? event.cell_id : event.cellId;
                    const isRandomEvent = event.is_random_event !== undefined ? event.is_random_event : event.isRandomEvent;
                    
                    console.log(`  Event #${index + 1}: Event ID=${eventId}, Cell ID=${cellId}, Is Random=${isRandomEvent}`);
                });
            } else {
                console.log('No events triggered by dice roll.');
            }
            
            // 检查掷骰子后触发的随机事件
            const diceRandomEvents = diceResponse.random_events || diceResponse.randomEvents;
            if (diceRandomEvents && Array.isArray(diceRandomEvents)) {
                console.log(`Found ${diceRandomEvents.length} random events in dice response:`);
                diceRandomEvents.forEach((event, index) => {
                    const eventId = event.event_id !== undefined ? event.event_id : event.eventId;
                    const cellId = event.cell_id !== undefined ? event.cell_id : event.cellId;
                    const isRandomEvent = event.is_random_event !== undefined ? event.is_random_event : event.isRandomEvent;
                    
                    console.log(`  Random Event #${index + 1}: Event ID=${eventId}, Cell ID=${cellId}, Is Random=${isRandomEvent}`);
                });
            } else {
                console.log('No random events in dice response.');
            }
            
            // 测试缓存
            console.log('\nTesting map info cache...');
            const secondResponse = await this.client.getMapInfo();
            
            // 获取第二次响应的数据，兼容不同的命名
            const secondChapterId = secondResponse.chapter_id !== undefined ? secondResponse.chapter_id : secondResponse.chapterId;
            const secondCurrentPosition = secondResponse.current_position !== undefined ? 
                secondResponse.current_position : secondResponse.currentPosition;
            const secondDirection = secondResponse.direction;
            
            // 比较核心数据而不是整个对象
            assert(chapterId === secondChapterId, 'Cached chapter_id should match');
            // 注意: 掷骰子后位置已经改变，所以不再比较 current_position
            assert(direction === secondDirection, 'Cached direction should match');
            
            // 测试: 断开重连验证
            console.log('\nTesting map info persistence after reconnect...');
            await this.client.close();
            await this.client.connect();
            const finalResponse = await this.client.getMapInfo();
            
            // 获取最终响应数据
            const finalChapterId = finalResponse.chapter_id !== undefined ? 
                finalResponse.chapter_id : finalResponse.chapterId;
                
            assert(finalChapterId === chapterId, 'Should have same chapter ID after reconnect');
            
            return true;
        } catch (error) {
            console.error('Get map info test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = GetMapInfoTest; 