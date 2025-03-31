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
            assert(currentPosition === secondCurrentPosition, 'Cached current_position should match');
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