const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class ClaimRewardTest extends BaseTest {
    constructor() {
        super('Claim Reward Test');
    }

    async test() {
        try {
            // 首先获取当前地图信息
            console.log('\nGetting current map info...');
            const mapInfo = await this.client.getMapInfo();
            assert(mapInfo, 'Map info should not be null');
            console.log('Map info keys:', Object.keys(mapInfo));
            
            // 获取属性，兼容不同的命名风格
            const chapterId = mapInfo.chapter_id !== undefined ? mapInfo.chapter_id : mapInfo.chapterId;
            const currentPosition = mapInfo.current_position !== undefined ? 
                mapInfo.current_position : mapInfo.currentPosition;
                
            console.log(`Current chapter: ${chapterId}, position: ${currentPosition}`);
            
            // 不断掷骰子直到到达终点位置
            let isAtEndPoint = false;
            let maxRolls = 20; // 设置最大掷骰子次数，避免无限循环
            let rollCount = 0;
            
            console.log('\n开始掷骰子直到到达终点...');
            
            while (!isAtEndPoint && rollCount < maxRolls) {
                rollCount++;
                console.log(`\n第 ${rollCount} 次掷骰子...`);
                
                // 掷骰子
                const rollResponse = await this.client.rollDice();
                assert(rollResponse, 'Roll response should not be null');
                console.log('Roll response keys:', Object.keys(rollResponse));
                
                // 检查是否到达终点
                const fromPosition = rollResponse.from_position !== undefined ? 
                    rollResponse.from_position : rollResponse.fromPosition;
                const toPosition = rollResponse.to_position !== undefined ? 
                    rollResponse.to_position : rollResponse.toPosition;
                    
                console.log(`掷骰子结果: from=${fromPosition}, to=${toPosition}`);
                
                // 如果当前位置与目标位置相同，表示已到达终点
                if (fromPosition === toPosition) {
                    console.log('到达终点位置，可以领取奖励了!');
                    isAtEndPoint = true;
                    continue; // 跳过事件处理，直接进入领取奖励阶段
                }
                
                // 获取事件列表
                const events = rollResponse.event_ids || rollResponse.eventIds || [];
                
                // 检查是否触发了事件
                if (!events || events.length === 0) {
                    console.log('没有触发任何事件，继续掷骰子...');
                    continue;
                }
                
                // 处理所有触发的事件
                await this.handleEvents(events);
                
                // 事件处理后等待一小段时间
                await new Promise(resolve => setTimeout(resolve, 500));
            }
            
            if (!isAtEndPoint) {
                console.log(`\n尝试了 ${rollCount} 次掷骰子，但未到达终点。尝试直接领取奖励...`);
            }
            
            return await this.claimChapterReward(chapterId);
        } catch (error) {
            console.error('Claim reward test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
    
    async handleEvents(events) {
        try {
            console.log(`\n处理 ${events.length} 个事件:`);
            events.forEach(event => {
                const eventId = event.event_id !== undefined ? event.event_id : event.eventId;
                const cellId = event.cell_id !== undefined ? event.cell_id : event.cellId;
                console.log(`  Event ID: ${eventId}, Cell ID: ${cellId}`);
            });
            
            // 循环处理所有事件
            for (let i = 0; i < events.length; i++) {
                const currentEvent = events[i];
                const eventId = currentEvent.event_id !== undefined ? 
                    currentEvent.event_id : currentEvent.eventId;
                const cellId = currentEvent.cell_id !== undefined ? 
                    currentEvent.cell_id : currentEvent.cellId;
                    
                console.log(`\n处理事件 ${i + 1}/${events.length} (ID: ${eventId}, Cell: ${cellId})...`);
                
                const response = await this.client.handleCellEvent(eventId, cellId);
                
                // 验证响应
                assert(response, 'Response should not be null');
                console.log('事件处理响应 keys:', Object.keys(response));
                
                // 验证必要的字段
                assert(response.success !== undefined, 'Response should have success field');
                
                // 检查事件处理是否成功
                if (!response.success) {
                    console.log(`警告: 事件 ${eventId} 处理失败`);
                    continue;
                }
                
                // 获取下一个事件ID和剩余事件
                const nextEventId = response.next_event_id !== undefined ? 
                    response.next_event_id : response.nextEventId;
                const remainingEvents = response.remaining_events || 
                    response.remainingEvents || [];
                    
                console.log(`下一个事件 ID: ${nextEventId}`);
                if (remainingEvents.length > 0) {
                    console.log(`剩余事件: ${remainingEvents.join(', ')}`);
                } else {
                    console.log('没有剩余事件');
                }
                
                // 如果有背包变化，记录变化
                const bags = response.bags || [];
                if (bags && bags.length > 0) {
                    console.log('检测到背包变化:');
                    bags.forEach(bag => {
                        const bagType = bag.bag_type !== undefined ? bag.bag_type : bag.bagType;
                        console.log(`背包类型: ${bagType}`);
                        
                        const items = bag.items || [];
                        if (items.length > 0) {
                            items.forEach(item => {
                                const itemId = item.item_id !== undefined ? item.item_id : item.itemId;
                                const count = item.count;
                                console.log(`  物品 ID: ${itemId}, 数量: ${count}`);
                            });
                        }
                    });
                }
            }
            
            return true;
        } catch (error) {
            console.error('处理事件失败:', error);
            throw error; // 重新抛出错误，让主流程捕获
        }
    }
    
    async claimChapterReward(chapterId) {
        try {
            // 获取奖励前的背包状态
            console.log('\n获取领取奖励前的背包信息...');
            const bagBefore = await this.client.getBagInfo();
            
            // 测试: 领取通关奖励
            console.log('\n尝试领取章节奖励...');
            const response = await this.client.claimReward();
            
            // 验证响应
            assert(response, 'Response should not be null');
            console.log('领取奖励响应 keys:', Object.keys(response));
            
            // 获取属性，兼容不同的命名风格
            const success = response.success;
            const bags = response.bags || [];
            const nextChapter = response.next_chapter !== undefined ? 
                response.next_chapter : response.nextChapter;
            
            // 验证字段
            assert(success !== undefined, 'Response should have success');
            
            // 检查领取状态
            if (!success) {
                console.log('领取奖励失败。可能需要处理更多事件才能完成章节。');
                return false;
            }
            
            console.log('成功领取章节奖励!');
            
            // 检查下一章节
            if (nextChapter !== undefined) {
                console.log(`下一章节: ${nextChapter}`);
                assert(nextChapter > chapterId, 
                    `Next chapter should be greater than current chapter (got: ${nextChapter})`);
            }
            
            // 如果有背包变化，验证变化
            if (bags && bags.length > 0) {
                console.log('\n检查背包变化...');
                const bagAfter = await this.client.getBagInfo();
                
                // 比较背包变化
                console.log('检测到背包变化:');
                bags.forEach(bag => {
                    const bagType = bag.bag_type !== undefined ? bag.bag_type : bag.bagType;
                    console.log(`背包类型: ${bagType}`);
                    
                    const items = bag.items || [];
                    if (items.length > 0) {
                        items.forEach(item => {
                            const itemId = item.item_id !== undefined ? item.item_id : item.itemId;
                            const count = item.count;
                            console.log(`  物品 ID: ${itemId}, 数量: ${count}`);
                        });
                    }
                });
            }
            
            // 获取最新地图信息，验证章节更新
            console.log('\n检查更新后的地图信息...');
            const updatedMapInfo = await this.client.getMapInfo();
            
            const updatedChapterId = updatedMapInfo.chapter_id !== undefined ? 
                updatedMapInfo.chapter_id : updatedMapInfo.chapterId;
            const updatedPosition = updatedMapInfo.current_position !== undefined ? 
                updatedMapInfo.current_position : updatedMapInfo.currentPosition;
            const updatedDirection = updatedMapInfo.direction;
            
            // 验证章节已更新
            if (nextChapter !== undefined) {
                assert(updatedChapterId === nextChapter, 
                    `Current chapter should be updated to next chapter (got: ${updatedChapterId})`);
            }
            
            console.log(`更新后的地图信息: 章节 ${updatedChapterId}, ` + 
                        `位置 ${updatedPosition}, ` + 
                        `方向 ${updatedDirection === 1 ? '前进' : '后退'}`);
            
            // 检查事件触发记录是否已重置
            const eventTriggers = updatedMapInfo.event_triggers || updatedMapInfo.eventTriggers;
            if (eventTriggers && Array.isArray(eventTriggers)) {
                console.log(`\n新章节中的事件触发记录: ${eventTriggers.length}个`);
                // 如果当前是第一章，事件触发记录应该是空的
                if (updatedChapterId === 1) {
                    assert(eventTriggers.length === 0, "新章节应该没有事件触发记录");
                } else {
                    eventTriggers.forEach((trigger, index) => {
                        const triggerChapterId = trigger.chapter_id !== undefined ? 
                            trigger.chapter_id : trigger.chapterId;
                        const eventId = trigger.event_id !== undefined ? 
                            trigger.event_id : trigger.eventId;
                        const triggerCount = trigger.trigger_count !== undefined ? 
                            trigger.trigger_count : trigger.triggerCount;
                        
                        console.log(`  触发记录 #${index + 1}: 章节ID=${triggerChapterId}, 事件ID=${eventId}, 计数=${triggerCount}`);
                        
                        // 验证触发记录的章节ID是否与当前章节匹配
                        assert(triggerChapterId === updatedChapterId, 
                            `触发记录的章节ID应该与当前章节匹配 (得到: ${triggerChapterId})`);
                    });
                }
            } else {
                console.log('\n新章节中没有事件触发记录');
            }
            
            return true;
        } catch (error) {
            console.error('领取奖励失败:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ClaimRewardTest;