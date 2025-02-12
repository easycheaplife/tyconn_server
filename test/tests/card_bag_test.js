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
                console.log('\n第一张卡牌详情:', {
                    cardId: result.cards[0].card_id,
                    cardType: result.cards[0].card_type,
                    level: result.cards[0].level,
                    exp: result.cards[0].exp,
                    quality: result.cards[0].quality,
                    star: result.cards[0].star,
                    createTime: new Date(result.cards[0].create_time * 1000).toISOString(),
                    count: result.cards[0].count
                });
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