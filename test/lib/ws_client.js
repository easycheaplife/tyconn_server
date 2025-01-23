const WebSocket = require('ws');

class WSClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
    }

    async connect() {
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(this.url);
            this.ws.on('open', () => resolve(this.ws));
            this.ws.on('error', reject);
        });
    }

    async waitForMessage() {
        return new Promise((resolve) => {
            this.ws.once('message', resolve);
        });
    }

    send(data) {
        this.ws.send(data);
    }

    close() {
        if (this.ws) {
            this.ws.close();
        }
    }
}

module.exports = WSClient; 