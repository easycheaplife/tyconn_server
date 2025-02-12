const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const CardBagBuilder = require('../builders/card_bag_builder');

class CardBagTest {
    constructor(root, ws_addr, ws_port) {
        this.root = root;
        this.ws_addr = ws_addr;
        this.ws_port = ws_port;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
    }

    async start() {
        try {
            // 检查token是否存在
            if (!global.token) {
                throw new Error('No token available');
            }

            // 连接服务器
            const wsUrl = `ws://${this.ws_addr}:${this.ws_port}`;
            this.wsClient = new WSClient(wsUrl);
            console.log('正在连接网关服务器:', wsUrl);
            await this.wsClient.connect();
            console.log('连接成功，开始获取背包...');

            // 发送背包请求
            const request = CardBagBuilder.build(this.root, global.token);
            this.wsClient.send(request);

            // 等待并处理响应
            const response = await this.wsClient.waitForMessage();
            if (!response) {
                console.error('未收到响应');
                this.stop();
                return false;
            }

            const result = this.responseHandler.handleCardBagResponse(response);
            if (!result) {
                console.error('获取背包失败');
                this.stop();
                return false;
            }

            // 打印背包信息
            console.log('\n背包信息:');
            console.log(`总卡牌数: ${result.cards.length}`);
            
            if (result.cards.length > 0) {
                console.log('\n所有卡牌详情:');
                result.cards.forEach((card, index) => {
                    console.log(`\n[卡牌 ${index + 1}]:`, {
                        cardId: card.card_id,
                        cardType: card.card_type,
                        level: card.level,
                        exp: card.exp,
                        quality: card.quality,
                        star: card.star,
                        createTime: new Date(card.create_time * 1000).toISOString(),
                        count: card.count
                    });
                });
            } else {
                console.log('背包中没有卡牌');
            }

            this.stop();
            return true;

        } catch (error) {
            console.error('背包测试失败:', error);
            this.stop();
            return false;
        }
    }

    stop() {
        if (this.wsClient) {
            this.wsClient.close();
        }
    }
}

module.exports = CardBagTest; 