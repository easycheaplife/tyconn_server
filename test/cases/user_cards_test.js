const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UserCardsTest extends BaseTest {
    constructor() {
        super('User Cards Test');
    }

    async test() {
        try {
            // 获取用户卡牌
            console.log('\nGetting user cards...');
            const userCards = await this.client.getUserCards();
            
            // 打印完整的响应内容以便调试
            console.log('User cards response:', JSON.stringify(userCards, null, 2));

            // 验证响应
            assert(userCards.cards, 'Missing cards in response');
            assert(Array.isArray(userCards.cards), 'Cards should be an array');

            // 验证每张卡牌的必要字段
            for (const card of userCards.cards) {
                console.log('Validating card:', card);
                // 检查 card_id 是否是 Long 或 number 类型
                assert(card.card_id && (typeof card.card_id === 'number' || 
                    (card.card_id.low !== undefined && card.card_id.high !== undefined)), 
                    'Invalid card_id type');
                // 获取实际的数值
                const cardId = typeof card.card_id === 'number' ? 
                    card.card_id : card.card_id.toNumber();
                assert(typeof card.level === 'number', 'Invalid level type');
                assert(typeof card.exp === 'number', 'Invalid exp type');
                assert(typeof card.star === 'number', 'Invalid star type');
                assert(typeof card.quality === 'number', 'Invalid quality type');
                assert(typeof card.power === 'number', 'Invalid power type');

                // 验证值的范围
                assert(cardId > 0, 'Invalid card_id value');
                assert(card.level > 0, 'Invalid level value');
                assert(card.exp >= 0, 'Invalid exp value');
                assert(card.star > 0, 'Invalid star value');
                assert(card.quality > 0, 'Invalid quality value');
                assert(card.power >= 0, 'Invalid power value');
            }

            return true;
        } catch (error) {
            console.error('Error in test:', error);
            return false;
        }
    }
}

module.exports = UserCardsTest; 