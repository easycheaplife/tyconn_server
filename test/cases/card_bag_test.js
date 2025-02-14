const BaseTest = require('../lib/base_test');

class CardBagTest extends BaseTest {
    constructor() {
        super('Card Bag Test');
    }

    async test() {
        try {
            // 获取卡包信息
            const response = await this.client.getCardBag();
            
            // 验证卡包信息
            if (!response) {
                console.error('Invalid card bag response: empty response');
                return false;
            }

            // 验证卡片列表
            if (!Array.isArray(response.cards)) {
                console.error('Invalid card bag response: cards is not an array');
                return false;
            }

            // 验证每张卡片的必要字段
            const requiredFields = [
                'card_id',      // 卡片ID
                'level',        // 等级
                'quality',      // 品质
                'star',         // 星级
                'create_time'   // 获得时间
            ];

            // 验证字段
            for (const card of response.cards) {
                for (const field of requiredFields) {
                    if (!(field in card)) {
                        console.error(`Missing required field: ${field}`);
                        return false;
                    }
                }
            }

            return true;

        } catch (error) {
            console.error('Card bag test failed:', error);
            return false;
        }
    }
}

module.exports = CardBagTest; 