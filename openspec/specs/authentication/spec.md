# Authentication

## Purpose

Redis Exporter 的认证能力：支持多种方式连接需要认证的 Redis 实例，以及保护 Exporter HTTP 端点。系统支持密码、ACL 用户、密码文件等多种 Redis 认证方式，同时提供 Basic Auth 保护 HTTP 端点安全。

## Requirements

### Requirement: Redis 密码认证

系统 SHALL 支持通过命令行参数、环境变量或密码文件向 Redis 实例提供认证密码。

#### Scenario: 命令行密码参数

- **GIVEN** `--redis.password=mypassword`
- **WHEN** 连接到 Redis 实例
- **THEN** 系统使用该密码进行 AUTH 认证

#### Scenario: 环境变量密码

- **GIVEN** 环境变量 `REDIS_PASSWORD=mypassword`
- **AND** 未设置命令行参数
- **WHEN** 连接到 Redis 实例
- **THEN** 系统使用环境变量中的密码进行认证

#### Scenario: URI 内嵌密码

- **GIVEN** Redis 地址为 `redis://:mypassword@localhost:6379`
- **WHEN** 连接到 Redis 实例
- **THEN** 系统从 URI 中提取密码进行认证

### Requirement: Redis ACL 用户认证

系统 SHALL 支持 Redis 6.0+ 的 ACL 用户名/密码认证。

#### Scenario: ACL 用户认证

- **GIVEN** `--redis.user=exporter` 和 `--redis.password=secret`
- **WHEN** 连接到 Redis 6.0+ 实例
- **THEN** 系统使用用户名和密码执行 AUTH 命令

#### Scenario: URI 内嵌用户名密码

- **GIVEN** Redis 地址为 `redis://exporter:secret@localhost:6379`
- **WHEN** 连接到 Redis 实例
- **THEN** 系统从 URI 中提取用户名和密码进行认证

### Requirement: 密码文件支持

系统 SHALL 支持从 JSON 密码文件加载多个 Redis 实例的密码映射。

#### Scenario: 加载密码文件

- **GIVEN** `--redis.password-file=pwd.json` 且文件内容为:
  ```json
  {
    "redis://host1:6379": "password1",
    "redis://host2:6379": "password2"
  }
  ```
- **WHEN** 通过 /scrape 端点抓取 host1
- **THEN** 系统使用 password1 连接 host1

#### Scenario: 密码文件优先级

- **GIVEN** `--redis.password=""` (空) 且设置了密码文件
- **WHEN** 连接到密码文件中定义的实例
- **THEN** 系统使用密码文件中的密码
- **NOTE** 密码文件仅在 `--redis.password` 为空时生效

#### Scenario: 热重载密码文件

- **GIVEN** 密码文件已加载
- **WHEN** 访问 `/-/reload` 端点
- **THEN** 系统重新加载密码文件，新密码立即生效

### Requirement: Exporter HTTP Basic Auth

系统 SHALL 支持通过 Basic Authentication 保护 Exporter HTTP 端点。

#### Scenario: 配置 Basic Auth

- **GIVEN** `--basic-auth-username=admin` 和 `--basic-auth-password=secret`
- **WHEN** 访问任何 HTTP 端点
- **THEN** 系统要求提供正确的 Basic Auth 凭据
- **AND** 未授权请求返回 401 Unauthorized

#### Scenario: Bcrypt 哈希密码

- **GIVEN** `--basic-auth-username=admin` 和 `--basic-auth-hash-password=$2a$...`
- **WHEN** 访问 HTTP 端点并提供正确密码
- **THEN** 系统使用 bcrypt 验证密码哈希

#### Scenario: Basic Auth 参数互斥

- **GIVEN** 同时设置 `--basic-auth-password` 和 `--basic-auth-hash-password`
- **WHEN** Exporter 启动
- **THEN** 系统报错并退出，两参数不能同时使用

### Requirement: 客户端名称设置

系统 SHALL 支持在 Redis 连接上设置客户端名称以便识别。

#### Scenario: 设置客户端名称

- **GIVEN** `--set-client-name=true` (默认)
- **WHEN** 连接到 Redis 实例
- **THEN** 系统执行 `CLIENT SETNAME redis_exporter`

#### Scenario: 禁用客户端名称

- **GIVEN** `--set-client-name=false`
- **WHEN** 连接到 Redis 实例
- **THEN** 系统不设置客户端名称

### Requirement: 最小权限 ACL

系统 SHALL 文档化 Exporter 所需的最小 Redis ACL 权限。

#### Scenario: 标准 Redis ACL 配置

- **GIVEN** 需要为 Exporter 创建专用 ACL 用户
- **WHEN** 配置 Redis ACL
- **THEN** 使用以下命令创建最小权限用户:
  ```
  ACL SETUSER exporter -@all +@connection +memory -readonly +strlen
  +config|get +xinfo +pfcount -quit +zcard +type +xlen -readwrite
  -command +client -wait +scard +llen +hlen +get +eval +slowlog
  +cluster|info +cluster|slots +cluster|nodes -hello -echo +info
  +latency +scan -reset -auth -asking >PASSWORD
  ```

#### Scenario: Sentinel ACL 配置

- **GIVEN** 需要监控 Sentinel 节点
- **WHEN** 配置 Sentinel ACL
- **THEN** 使用以下命令:
  ```
  ACL SETUSER exporter -@all +@connection -command +client -hello
  +info -auth +sentinel|masters +sentinel|replicas +sentinel|slaves
  +sentinel|sentinels +sentinel|ckquorum >PASSWORD
  ```

## Design Notes

### 密码文件格式

密码文件必须是 JSON 格式，键为完整的 Redis URI（包含 `redis://` 前缀），值为密码字符串。

### 认证优先级

1. URI 中的密码 (最高)
2. 命令行 `--redis.password`
3. 环境变量 `REDIS_PASSWORD`
4. 密码文件 (仅当上述为空时)

### 实现位置

- 密码文件加载: `exporter/pwd_file.go`
- Basic Auth: `exporter/http.go` - `verifyBasicAuth()`
- Redis 认证: `exporter/redis.go` - `connectToRedis()`
- 密码重载: `exporter/http.go` - `reloadPwdFile()`

