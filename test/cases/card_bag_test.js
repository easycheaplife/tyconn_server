const BaseTest = require('../lib/base_test');

class CardBagTest extends BaseTest {
    constructor() {
        super('Card Bag Test');
    }

    async test() {
        try {
            // 获取卡包信息
            const response = await this.client.getCardBag();
            console.log('Card bag response:', response);

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
            for (const card of response.cards) {
                const requiredFields = [
                    'card_id',    // 卡片ID
                    'level',      // 等级
                    'quality',    // 品质
                    'star',       // 星级
                    'create_time' // 创建时间
                ];
                
                for (const field of requiredFields) {
                    if (card[field] === undefined) {
                        console.error(`Missing required field in card: ${field}`);
                        return false;
                    }
                }

                // 验证字段类型和值的合理性
                if (card.level < 1) {
                    console.error(`Invalid card level: ${card.level}`);
                    return false;
                }
                if (card.quality < 1) {
                    console.error(`Invalid card quality: ${card.quality}`);
                    return false;
                }
                if (card.star < 1) {
                    console.error(`Invalid card star: ${card.star}`);
                    return false;
                }
            }

            // 验证响应消息
            if (!response.message) {
                console.error('Missing response message');
                return false;
            }

            // 所有验证通过
            console.log('Card bag validation passed:');
            console.log(`- Total cards: ${response.cards.length}`);
            console.log(`- Message: ${response.message}`);
            return true;

        } catch (error) {
            console.error('Card bag test failed:', error);
            return false;
        }
    }
}

module.exports = CardBagTest; 