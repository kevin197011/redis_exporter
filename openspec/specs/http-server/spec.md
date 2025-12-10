# HTTP Server

## Purpose

Redis Exporter 的 HTTP 服务能力：提供 Prometheus 指标端点和多目标抓取支持。系统暴露标准的 `/metrics` 端点供 Prometheus 抓取，并提供 `/scrape` 端点实现多目标动态抓取模式。

## Requirements

### Requirement: 指标端点

系统 SHALL 在可配置路径提供 Prometheus 格式的指标端点。

#### Scenario: 默认指标端点

- **GIVEN** 默认配置
- **WHEN** GET `/metrics`
- **THEN** 系统返回 Prometheus 文本格式的所有指标
- **AND** Content-Type 为 `text/plain; charset=utf-8`

#### Scenario: 自定义指标路径

- **GIVEN** `--web.telemetry-path=/custom/metrics`
- **WHEN** GET `/custom/metrics`
- **THEN** 系统返回 Prometheus 指标

#### Scenario: 支持 zstd 压缩

- **GIVEN** 客户端发送 `Accept-Encoding: zstd`
- **WHEN** GET `/metrics`
- **THEN** 系统返回 zstd 压缩的响应 (如果 promhttp 支持)

### Requirement: 监听配置

系统 SHALL 支持配置 HTTP 服务监听地址和端口。

#### Scenario: 默认监听地址

- **GIVEN** 默认配置
- **WHEN** Exporter 启动
- **THEN** 系统监听 `0.0.0.0:9121`

#### Scenario: 自定义监听地址

- **GIVEN** `--web.listen-address=127.0.0.1:8080`
- **WHEN** Exporter 启动
- **THEN** 系统监听 `127.0.0.1:8080`

### Requirement: 多目标抓取端点

系统 SHALL 提供 `/scrape` 端点支持 Prometheus 多目标抓取模式。

#### Scenario: 抓取远程 Redis

- **GIVEN** Exporter 启动（可以不配置默认 Redis 地址）
- **WHEN** GET `/scrape?target=redis://remote:6379`
- **THEN** 系统连接到 remote:6379
- **AND** 返回该实例的指标

#### Scenario: 自动添加协议前缀

- **GIVEN** target 参数没有协议前缀
- **WHEN** GET `/scrape?target=remote:6379`
- **THEN** 系统自动添加 `redis://` 前缀

#### Scenario: 动态覆盖选项

- **GIVEN** `/scrape` 请求带有查询参数
- **WHEN** GET `/scrape?target=host:6379&check-keys=db0=mykey*`
- **THEN** 系统使用请求中的 check-keys 参数覆盖默认配置

#### Scenario: 支持的动态参数

- **GIVEN** `/scrape` 端点
- **WHEN** 请求包含以下参数
- **THEN** 系统支持动态覆盖:
  - `check-keys`
  - `check-single-keys`
  - `check-streams`
  - `check-single-streams`
  - `count-keys`

#### Scenario: Target 参数必须

- **GIVEN** `/scrape` 端点
- **WHEN** GET `/scrape` (无 target 参数)
- **THEN** 返回 400 Bad Request
- **AND** 错误消息说明 target 参数必须

#### Scenario: 用户凭据处理

- **GIVEN** target URL 包含用户名
- **WHEN** GET `/scrape?target=redis://user@host:6379`
- **THEN** 系统提取用户名用于认证
- **AND** 从 URL 中移除用户信息（安全考虑）

### Requirement: 健康检查端点

系统 SHALL 提供健康检查端点。

#### Scenario: 健康检查

- **WHEN** GET `/health`
- **THEN** 返回 200 OK
- **AND** 响应体为 `ok`

### Requirement: 首页

系统 SHALL 提供包含版本信息和指标链接的首页。

#### Scenario: 访问首页

- **WHEN** GET `/`
- **THEN** 返回 HTML 页面
- **AND** 显示 Exporter 版本
- **AND** 包含指向 `/metrics` 的链接

### Requirement: 密码文件重载端点

系统 SHALL 提供端点用于热重载密码文件。

#### Scenario: 重载密码文件

- **GIVEN** 配置了 `--redis.password-file`
- **WHEN** POST `/-/reload`
- **THEN** 系统重新加载密码文件
- **AND** 返回 `ok`

#### Scenario: 未配置密码文件

- **GIVEN** 未配置密码文件
- **WHEN** POST `/-/reload`
- **THEN** 返回 400 Bad Request
- **AND** 错误消息说明未指定密码文件

#### Scenario: 重载失败

- **GIVEN** 密码文件格式错误
- **WHEN** POST `/-/reload`
- **THEN** 返回 500 Internal Server Error
- **AND** 错误消息包含解析错误详情

### Requirement: 集群发现端点

系统 SHALL 提供端点用于 Prometheus 动态发现集群节点（详见 cluster-support spec）。

#### Scenario: 发现集群节点

- **GIVEN** `--is-cluster=true`
- **WHEN** GET `/discover-cluster-nodes`
- **THEN** 返回 Prometheus HTTP SD 格式的 JSON

### Requirement: 优雅关闭

系统 SHALL 支持优雅关闭 HTTP 服务器。

#### Scenario: 接收终止信号

- **GIVEN** Exporter 正在运行
- **WHEN** 收到 SIGINT 或 SIGTERM 信号
- **THEN** 系统:
  - 停止接受新连接
  - 等待现有请求完成（最多 10 秒）
  - 记录关闭日志
  - 优雅退出

### Requirement: TLS 服务器

系统 SHALL 支持 HTTPS 服务（详见 tls-security spec）。

#### Scenario: 启用 HTTPS

- **GIVEN** 配置了 TLS 服务器证书和密钥
- **WHEN** Exporter 启动
- **THEN** 系统使用 HTTPS 而非 HTTP

## Design Notes

### Prometheus 多目标配置示例

```yaml
scrape_configs:
  - job_name: 'redis_exporter_targets'
    static_configs:
      - targets:
        - redis://host1:6379
        - redis://host2:6379
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: exporter:9121
```

### 端点汇总

| 端点 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 首页，显示版本和链接 |
| `/metrics` | GET | Prometheus 指标端点 |
| `/scrape` | GET | 多目标抓取端点 |
| `/health` | GET | 健康检查 |
| `/-/reload` | GET/POST | 重载密码文件 |
| `/discover-cluster-nodes` | GET | 集群节点发现 |

### 实现位置

- HTTP 路由: `exporter/exporter.go` - `NewRedisExporter()` 中 mux 设置
- HTTP Handlers: `exporter/http.go`
- 主服务器: `main.go` - 服务器启动和优雅关闭

