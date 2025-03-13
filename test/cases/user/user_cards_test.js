const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class UserCardsTest extends BaseTest {
    constructor() {
        super('User Cards Test');
    }

    async test() {
        try {
            // 测试1: 获取用户卡牌列表
            console.log('\nTesting get user cards...');
            const response = await this.client.getUserCards();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.cards), 'Cards should be an array');
            assert(response.cards.length > 0, 'User should have at least one card');

            // 验证卡牌字段
            for (const card of response.cards) {
                // 基本字段验证
                assert(card.card_id && typeof card.card_id.low === 'number', 'Card ID should be a Long');
                assert(card.level >= 1, 'Card level should be at least 1');
                assert(card.exp && typeof card.exp.low === 'number', 'Card exp should be a Long');
                assert(card.star >= 1, 'Card star should be at least 1');

                // 模板ID范围验证
                assert(card.card_type >= 1 && card.card_type <= 9999, 
                    'Card type should be in valid range');
            }

            // 测试2: 缓存验证
            console.log('\nTesting cards cache...');
            const secondResponse = await this.client.getUserCards();
            assert.deepStrictEqual(response.cards, secondResponse.cards, 
                'Cached cards should match');

            // 测试3: 断开重连验证
            console.log('\nTesting cards persistence after reconnect...');
            await this.client.close();
            await this.client.connect();
            const thirdResponse = await this.client.getUserCards();
            assert.deepStrictEqual(response.cards, thirdResponse.cards, 
                'Cards should persist after reconnect');

            // 测试4: 卡牌唯一性验证
            console.log('\nTesting card uniqueness...');
            const cardIds = new Set(response.cards.map(card => card.card_id.low));
            assert.strictEqual(cardIds.size, response.cards.length, 
                'Each card should have a unique ID');

            // 测试5: 卡牌数量限制
            console.log('\nTesting card count limits...');
            assert(response.cards.length <= 100, 'User should not have more than 100 cards');

            // 测试6: 卡牌模板分布
            console.log('\nTesting card template distribution...');
            const templateIds = new Set(response.cards.map(card => card.card_type));
            assert(templateIds.size > 0, 'Should have cards from different templates');

            // 测试7: 卡牌属性范围验证
            console.log('\nTesting card property ranges...');
            for (const card of response.cards) {
                // 等级范围
                assert(card.level >= 1 && card.level <= 100, 
                    'Card level should be between 1 and 100');
                
                // 星级范围
                assert(card.star >= 1 && card.star <= 5, 
                    'Card star should be between 1 and 5');
                
                // 经验值范围
                assert(card.exp.low >= 0, 'Card exp should not be negative');
            }

            return true;
        } catch (error) {
            console.error('User cards test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UserCardsTest; 