# TLS Security

## Purpose

Redis Exporter 的 TLS 安全能力：支持与 Redis 的 TLS 加密连接，以及 Exporter HTTP 服务的 HTTPS。系统支持客户端证书认证（mTLS）、自定义 CA、以及 HTTPS 服务器端 TLS 配置。

## Requirements

### Requirement: Redis TLS 连接

系统 SHALL 支持通过 TLS 加密连接到 Redis 实例。

#### Scenario: 使用 rediss:// 协议

- **GIVEN** Redis 地址为 `rediss://redis.example.com:6379`
- **WHEN** 连接到 Redis
- **THEN** 系统使用 TLS 加密连接

#### Scenario: 使用 valkeys:// 协议

- **GIVEN** Redis 地址为 `valkeys://valkey.example.com:6379`
- **WHEN** 连接到 Redis
- **THEN** 系统使用 TLS 加密连接（内部转换为 rediss://）

### Requirement: TLS 客户端证书认证

系统 SHALL 支持 TLS 双向认证（mTLS），使用客户端证书连接 Redis。

#### Scenario: 配置客户端证书

- **GIVEN** 配置了:
  - `--tls-client-cert-file=/path/to/client.crt`
  - `--tls-client-key-file=/path/to/client.key`
- **WHEN** 连接到要求客户端证书的 Redis
- **THEN** 系统使用客户端证书进行 TLS 握手

#### Scenario: 客户端证书配置验证

- **GIVEN** 只配置了 `--tls-client-cert-file` 而没有 `--tls-client-key-file`
- **WHEN** Exporter 启动
- **THEN** 系统报错退出
- **AND** 错误消息说明证书和密钥文件必须同时提供

### Requirement: TLS CA 证书

系统 SHALL 支持自定义 CA 证书验证 Redis 服务器证书。

#### Scenario: 配置自定义 CA

- **GIVEN** `--tls-ca-cert-file=/path/to/ca.crt`
- **WHEN** 连接到 Redis
- **THEN** 系统使用指定的 CA 证书验证服务器证书

#### Scenario: 默认系统 CA

- **GIVEN** 未配置 `--tls-ca-cert-file`
- **WHEN** 连接到 Redis
- **THEN** 系统使用系统默认的 CA 证书池

### Requirement: 跳过 TLS 验证

系统 SHALL 支持跳过 TLS 证书验证（仅用于测试）。

#### Scenario: 跳过证书验证

- **GIVEN** `--skip-tls-verification=true`
- **WHEN** 连接到 Redis
- **THEN** 系统不验证服务器证书
- **AND** 日志记录警告（不推荐在生产环境使用）

### Requirement: HTTPS 服务器

系统 SHALL 支持使用 HTTPS 提供 Exporter HTTP 服务。

#### Scenario: 配置 HTTPS 服务器

- **GIVEN** 配置了:
  - `--tls-server-cert-file=/path/to/server.crt`
  - `--tls-server-key-file=/path/to/server.key`
- **WHEN** Exporter 启动
- **THEN** 系统使用 HTTPS 而非 HTTP
- **AND** 监听配置的地址和端口

#### Scenario: 仅提供部分服务器证书

- **GIVEN** 只配置了 `--tls-server-cert-file` 而没有 `--tls-server-key-file`
- **WHEN** Exporter 启动
- **THEN** 系统使用 HTTP（因为证书配置不完整）

### Requirement: HTTPS 客户端认证

系统 SHALL 支持 HTTPS 服务器要求客户端证书认证。

#### Scenario: 配置服务器端 CA

- **GIVEN** 配置了:
  - `--tls-server-cert-file`
  - `--tls-server-key-file`
  - `--tls-server-ca-cert-file=/path/to/client-ca.crt`
- **WHEN** 客户端连接到 Exporter
- **THEN** 系统要求客户端提供有效证书
- **AND** 使用指定的 CA 验证客户端证书

### Requirement: TLS 版本控制

系统 SHALL 支持配置 HTTPS 服务器的最低 TLS 版本。

#### Scenario: 默认 TLS 版本

- **GIVEN** 默认配置
- **WHEN** HTTPS 服务器启动
- **THEN** 最低 TLS 版本为 TLS 1.2

#### Scenario: 配置最低 TLS 版本

- **GIVEN** `--tls-server-min-version=TLS1.3`
- **WHEN** 客户端使用 TLS 1.2 连接
- **THEN** 连接被拒绝

#### Scenario: 支持的 TLS 版本

- **GIVEN** `--tls-server-min-version` 参数
- **THEN** 系统支持以下值:
  - `TLS1.0`
  - `TLS1.1`
  - `TLS1.2` (默认)
  - `TLS1.3`

## Design Notes

### TLS 配置参数汇总

| 参数 | 环境变量 | 说明 |
|------|----------|------|
| `--tls-client-key-file` | `REDIS_EXPORTER_TLS_CLIENT_KEY_FILE` | 客户端私钥文件 |
| `--tls-client-cert-file` | `REDIS_EXPORTER_TLS_CLIENT_CERT_FILE` | 客户端证书文件 |
| `--tls-ca-cert-file` | `REDIS_EXPORTER_TLS_CA_CERT_FILE` | Redis CA 证书 |
| `--skip-tls-verification` | `REDIS_EXPORTER_SKIP_TLS_VERIFICATION` | 跳过验证 |
| `--tls-server-key-file` | `REDIS_EXPORTER_TLS_SERVER_KEY_FILE` | 服务器私钥 |
| `--tls-server-cert-file` | `REDIS_EXPORTER_TLS_SERVER_CERT_FILE` | 服务器证书 |
| `--tls-server-ca-cert-file` | `REDIS_EXPORTER_TLS_SERVER_CA_CERT_FILE` | 客户端 CA |
| `--tls-server-min-version` | `REDIS_EXPORTER_TLS_SERVER_MIN_VERSION` | 最低 TLS 版本 |

### 测试证书生成

项目提供测试证书生成脚本：`contrib/tls/gen-test-certs.sh`

### Azure Redis TLS 示例

```
rediss://azure-ssl-enabled-host.redis.cache.windows.net:6380
```

注意：Azure Redis 使用非标准端口 6380，必须在 URL 中指定。

### 实现位置

- TLS 配置创建: `exporter/tls.go`
  - `CreateClientTLSConfig()` - 客户端 TLS 配置
  - `CreateServerTLSConfig()` - 服务器 TLS 配置
- TLS 连接: `exporter/redis.go` - 连接时应用 TLS 配置
- 服务器启动: `main.go` - 根据配置选择 HTTP/HTTPS

