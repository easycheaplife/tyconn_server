# 创建证书目录
mkdir -p nginx/cert

# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout nginx/cert/server.key \
			-out nginx/cert/server.crt

# Nginx 配置说明

## 端口配置

### WebSocket 端口
- 登录服务器: 8021 (由 nginx 代理)
- 游戏网关1: 8031 (由登录服务器负载均衡)
- 游戏网关2: 8032 (由登录服务器负载均衡)

### 代理端口
- HTTP/WS代理: 8010 (代理到登录服务器)
- HTTPS/WSS代理: 8011 (代理到登录服务器)

## 负载均衡

登录服务器代理：

```nginx
upstream login_server {
    server 127.0.0.1:8021;
}
```

注意：游戏网关的负载均衡由登录服务器实现，nginx 只需要代理登录服务器。

## SSL 配置

HTTPS/WSS 需要配置 SSL 证书：

```nginx
ssl_certificate     /data/tyconn_server/nginx/server.crt;
ssl_certificate_key /data/tyconn_server/nginx/server.key;
ssl_protocols       TLSv1.2 TLSv1.3;
ssl_ciphers        HIGH:!aNULL:!MD5;
```

## WebSocket 配置

需要配置以下 header 以支持 WebSocket：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

## 超时配置

WebSocket 连接超时设置：

```nginx
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```
