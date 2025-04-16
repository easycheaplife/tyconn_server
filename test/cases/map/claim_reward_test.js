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
            
            // 获取奖励前的背包状态
            console.log('\nGetting bag info before claiming reward...');
            const bagBefore = await this.client.getBagInfo();
            
            // 测试: 领取通关奖励
            console.log('\nTesting claim reward...');
            const response = await this.client.claimReward();
            
            // 验证响应
            assert(response, 'Response should not be null');
            console.log('Claim reward response keys:', Object.keys(response));
            
            // 获取属性，兼容不同的命名风格
            const success = response.success;
            const bags = response.bags || [];
            const nextChapter = response.next_chapter !== undefined ? 
                response.next_chapter : response.nextChapter;
            
            // 验证字段
            assert(success !== undefined, 'Response should have success');
            assert(Array.isArray(bags), 'bags should be an array');
            assert(nextChapter !== undefined, 'Response should have next_chapter or nextChapter');
            
            // 检查领取状态
            assert(success, 'Reward claim should succeed');
            
            // 检查下一章节
            assert(nextChapter > chapterId, 
                `Next chapter should be greater than current chapter (got: ${nextChapter})`);
            console.log(`Next chapter: ${nextChapter}`);
            
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
            
            // 获取最新地图信息，验证章节更新
            console.log('\nChecking updated map info...');
            const updatedMapInfo = await this.client.getMapInfo();
            
            const updatedChapterId = updatedMapInfo.chapter_id !== undefined ? 
                updatedMapInfo.chapter_id : updatedMapInfo.chapterId;
            const updatedPosition = updatedMapInfo.current_position !== undefined ? 
                updatedMapInfo.current_position : updatedMapInfo.currentPosition;
            const updatedDirection = updatedMapInfo.direction;
            
            assert(updatedChapterId === nextChapter, 
                `Current chapter should be updated to next chapter (got: ${updatedChapterId})`);
            assert(updatedPosition === 1, 
                `Current position should be reset to 0 (got: ${updatedPosition})`);
            
            console.log(`Updated map info: Chapter ${updatedChapterId}, ` + 
                        `Position ${updatedPosition}, ` + 
                        `Direction ${updatedDirection === 1 ? 'Forward' : 'Backward'}`);
            
            return true;
        } catch (error) {
            console.error('Claim reward test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ClaimRewardTest;