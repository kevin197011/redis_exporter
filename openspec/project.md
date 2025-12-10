# Project Context

## Purpose

Redis Exporter 是一个 Prometheus 指标导出器，用于从 Redis/Valkey 实例收集和导出监控指标。它支持多种 Redis 兼容系统（Redis 2.x-7.x、Valkey、KeyDB、Tile38），为 Prometheus 监控生态系统提供完整的 Redis 可观测性解决方案。

## Tech Stack

- **语言**: Go 1.25.0
- **核心依赖**:
  - `github.com/gomodule/redigo` v1.9.3 - Redis 客户端
  - `github.com/mna/redisc` v1.4.0 - Redis Cluster 支持
  - `github.com/prometheus/client_golang` v1.23.2 - Prometheus 客户端
  - `github.com/sirupsen/logrus` v1.9.3 - 日志框架
  - `golang.org/x/crypto` - 加密支持 (bcrypt)
- **容器化**: Docker, Docker Compose
- **编排**: Kubernetes, OpenShift
- **监控**: Prometheus, Grafana

## Project Conventions

### Code Style

- 遵循 Go 标准代码风格 (gofmt)
- 使用 golangci-lint 进行代码质量检查
- 包命名使用小写单词
- 导出函数/类型使用 PascalCase
- 私有函数/变量使用 camelCase
- 常量使用全大写下划线分隔

### Architecture Patterns

- **单体应用架构**: 所有功能在一个二进制文件中
- **模块化设计**: 核心功能在 `exporter/` 包中分文件组织
- **Prometheus Collector 模式**: 实现 `prometheus.Collector` 接口
- **HTTP Handler 模式**: 标准库 `net/http` 实现 HTTP 服务
- **配置优先级**: 命令行参数 > 环境变量 > 默认值

### File Organization

```
redis_exporter/
├── main.go                 # 入口点，命令行参数解析
├── exporter/               # 核心导出器逻辑
│   ├── exporter.go         # Exporter 结构和 Prometheus Collector 实现
│   ├── http.go             # HTTP handlers
│   ├── redis.go            # Redis 连接管理
│   ├── info.go             # INFO 命令解析
│   ├── keys.go             # 键检查逻辑
│   ├── streams.go          # Stream 指标
│   ├── clients.go          # 客户端列表指标
│   ├── sentinels.go        # Sentinel 指标
│   ├── nodes.go            # Cluster 节点指标
│   ├── lua.go              # Lua 脚本执行
│   ├── tls.go              # TLS 配置
│   ├── metrics.go          # 指标注册辅助
│   └── *_test.go           # 对应测试文件
├── contrib/                # 社区贡献资源
│   ├── redis-mixin/        # Prometheus mixin (dashboards, alerts, rules)
│   ├── k8s-*.yaml          # Kubernetes 部署配置
│   └── tls/                # TLS 测试证书生成
├── docker-compose.yml      # 测试环境配置
├── Dockerfile              # Docker 镜像构建
└── Makefile                # 构建和测试命令
```

### Testing Strategy

- **单元测试**: 每个核心文件对应 `*_test.go`
- **集成测试**: 使用 Docker Compose 启动真实 Redis 实例
- **测试覆盖率**: 目标 ≥ 80%，关键路径 100%
- **运行测试**: `make docker-test` 或 `make test`
- **支持的测试实例**: Redis 2.8/5/6/7/8, Valkey 7/8, KeyDB, Tile38, Sentinel, Cluster

### Git Workflow

- 主分支: `master`
- 提交规范: Conventional Commits
- PR 合并前需通过 CI 检查 (GitHub Actions)
- 版本发布: GitHub Releases + Docker Hub + ghcr.io + quay.io

## Domain Context

### Prometheus 指标模型

- **Gauge**: 可增减的值（如连接数、内存使用）
- **Counter**: 只增不减的累计值（如命令执行次数）
- **Summary**: 分位数统计（如延迟分布）
- **Histogram**: 直方图统计（如延迟直方图）

### Redis 数据源

- **INFO 命令**: 大部分指标来源
- **CONFIG GET**: 配置指标
- **CLIENT LIST**: 客户端连接指标
- **SLOWLOG**: 慢查询指标
- **CLUSTER INFO/NODES**: 集群指标
- **SENTINEL MASTERS**: Sentinel 指标
- **MEMORY USAGE**: 键内存使用
- **SCAN**: 键扫描
- **LATENCY HISTOGRAM**: 延迟直方图 (Redis 7+)

### 指标命名规范

- 前缀: 可配置，默认 `redis_`
- 命名: snake_case
- 单位后缀: `_bytes`, `_seconds`, `_total`
- 标签: db, key, cmd, instance 等

## Important Constraints

### 安全约束

- 敏感配置（密码、密钥）禁止硬编码
- 支持密码文件和环境变量注入
- CONFIG 指标默认脱敏 (redact)
- 支持 TLS 客户端认证
- Exporter HTTP 端点支持 Basic Auth

### 性能约束

- Redis 是单线程，大量 SCAN/MEMORY USAGE 会影响性能
- `check-keys-batch-size` 控制 SCAN COUNT
- 避免在高负载 master 上执行键检查
- `skip-checkkeys-for-role-master` 选项

### 兼容性约束

- 支持 Redis 2.x - 7.x (部分指标版本限定)
- 支持 Valkey (valkey:// 协议)
- 支持 KeyDB 特有指标
- 支持 Tile38 地理数据库

## External Dependencies

### 运行时依赖

- Redis/Valkey 实例 (被监控目标)
- Prometheus Server (抓取指标)
- Grafana (可选，可视化)

### 开发依赖

- Docker / Docker Compose (测试环境)
- golangci-lint (代码检查)
- gox (跨平台编译)

### 发布渠道

- GitHub Releases (二进制)
- Docker Hub: `oliver006/redis_exporter`
- GitHub Container Registry: `ghcr.io/oliver006/redis_exporter`
- Quay.io: `quay.io/oliver006/redis_exporter`
