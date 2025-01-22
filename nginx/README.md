```
# 创建证书目录
mkdir -p nginx/cert

# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout nginx/cert/server.key \
			-out nginx/cert/server.crt
```
