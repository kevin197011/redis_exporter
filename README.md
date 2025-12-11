# Prometheus Valkey & Redis 指标导出器


[![Docker Build](https://github.com/kevin197011/redis_exporter/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/kevin197011/redis_exporter/actions/workflows/docker-publish.yml)

用于 Valkey 指标的 Prometheus 导出器（Redis 兼容）。\
支持 Valkey 和 Redis 2.x、3.x、4.x、5.x、6.x 和 7.x

[English Documentation](README-en.md)

## 构建和运行导出器

### 本地构建和运行

```sh
git clone https://github.com/kevin197011/redis_exporter.git
cd redis_exporter
go build .
./redis_exporter --version
```

### 预编译二进制文件

预编译的二进制文件请查看 [发布页面](https://github.com/kevin197011/redis_exporter/releases)。

### 基础 Prometheus 配置

在 prometheus.yml 配置文件的 `scrape_configs` 中添加以下配置块：

```yaml
scrape_configs:
  - job_name: redis_exporter
    static_configs:
    - targets: ['<<REDIS-EXPORTER-HOSTNAME>>:9121']
```

并相应调整主机名。

### Kubernetes SD 配置

为了在下拉菜单中显示可读的实例名称而不是 IP，建议使用 [实例重标签](https://www.robustperception.io/controlling-the-instance-label)。

例如，如果通过 pod 角色抓取指标，可以添加：

```yaml
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: instance
            regex: (.*redis.*)
```

作为相应抓取配置的重标签配置。根据正则表达式值，只有名称中包含 "redis" 的 pod 才会被这样重标签。

根据如何检索抓取目标，可以对 [其他角色类型](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config) 采用类似的方法。

### 抓取多个 Redis 主机的 Prometheus 配置

Prometheus 文档有一篇 [非常有价值的文章](https://prometheus.io/docs/guides/multi-target-exporter/) 介绍多目标导出器的工作原理。

使用命令行参数 `--redis.addr=` 运行导出器，这样每次抓取 `/metrics` 端点时就不会尝试访问本地实例。使用以下配置时，prometheus 将使用 /scrape 端点而不是 /metric 端点。例如，第一个目标将通过以下 web 请求查询：
http://exporterhost:9121/scrape?target=first-redis-host:6379

```yaml
scrape_configs:
  ## 导出器将抓取的多个 Redis 目标的配置
  - job_name: 'redis_exporter_targets'
    static_configs:
      - targets:
        - redis://first-redis-host:6379
        - redis://second-redis-host:6379
        - redis://second-redis-host:6380
        - redis://second-redis-host:6381
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: <<REDIS-EXPORTER-HOSTNAME>>:9121

  ## 抓取导出器本身的配置
  - job_name: 'redis_exporter'
    static_configs:
      - targets:
        - <<REDIS-EXPORTER-HOSTNAME>>:9121
```

Redis 实例在 `targets` 下列出，Redis 导出器主机名通过最后一个 relabel_config 规则配置。\
如果 Redis 实例需要认证，可以通过导出器的 `--redis.password` 命令行选项设置密码（这意味着目前只能在此方式抓取的所有实例中使用一个密码。如果这是个问题，请使用多个导出器）。\
您也可以使用 json 文件通过 `file_sd_configs` 提供多个目标，如下所示：

```yaml
scrape_configs:
  - job_name: 'redis_exporter_targets'
    file_sd_configs:
      - files:
        - targets-redis-instances.json
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: <<REDIS-EXPORTER-HOSTNAME>>:9121

  ## 抓取导出器本身的配置
  - job_name: 'redis_exporter'
    static_configs:
      - targets:
        - <<REDIS-EXPORTER-HOSTNAME>>:9121
```

`targets-redis-instances.json` 文件应该类似这样：

```json
[
  {
    "targets": [ "redis://redis-host-01:6379", "redis://redis-host-02:6379"],
    "labels": { }
  }
]
```

Prometheus 使用文件监视，对 json 文件的所有更改会立即生效。

### 抓取 Redis 集群所有节点的 Prometheus 配置

使用 Redis 集群时，导出器提供了一个发现端点，可用于发现集群中的所有节点。
要使用此功能，必须使用 `--is-cluster` 参数启动导出器。\
发现端点位于 `/discover-cluster-nodes`，可以在 Prometheus 配置中这样使用：

```yaml
scrape_configs:
  - job_name: 'redis_exporter_cluster_nodes'
    http_sd_configs:
      - url: http://<<REDIS-EXPORTER-HOSTNAME>>:9121/discover-cluster-nodes
        refresh_interval: 10m
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: <<REDIS-EXPORTER-HOSTNAME>>:9121

  ## 抓取导出器本身的配置
  - job_name: 'redis_exporter'
    static_configs:
      - targets:
        - <<REDIS-EXPORTER-HOSTNAME>>:9121
```

### 命令行参数

| 名称 | 环境变量名 | 描述 |
|------|-----------|------|
| redis.addr | REDIS_ADDR | Redis 实例地址，默认为 `redis://localhost:6379`。如果启用 TLS，地址必须像这样 `rediss://localhost:6379` |
| redis.user | REDIS_USER | 用于认证的用户名（Redis 6.0 及更新版本的 Redis ACL）|
| redis.password | REDIS_PASSWORD | Redis 实例密码，默认为 `""`（无密码）|
| redis.password-file | REDIS_PASSWORD_FILE | 要抓取的 Redis 实例的密码文件，默认为 `""`（无密码文件）|
| check-keys | REDIS_EXPORTER_CHECK_KEYS | 要导出值和长度/大小的键模式的逗号分隔列表，例如：`db3=user_count` 将从 db `3` 导出键 `user_count`。如果省略 db，默认为 `0`。使用 [SCAN](https://valkey.io/commands/scan) 查找。如果需要 glob 模式匹配请使用此选项；对于非模式键，`check-single-keys` 更快。警告：使用 `--check-keys` 匹配大量键可能会使导出器变慢甚至无法完成抓取。在集群模式下不工作，因为 "SCAN" 不能跨多个实例工作。|
| check-single-keys | REDIS_EXPORTER_CHECK_SINGLE_KEYS | 要导出值和长度/大小的键的逗号分隔列表，例如：`db3=user_count` 将从 db `3` 导出键 `user_count`。如果省略 db，默认为 `0`。此参数指定的键将直接查找，不使用任何 glob 模式匹配。如果不需要 glob 模式匹配，使用此选项；它比 `check-keys` 更快。|
| check-streams | REDIS_EXPORTER_CHECK_STREAMS | 要导出 streams、groups 和 consumers 信息的 stream 模式的逗号分隔列表。语法与 `check-keys` 相同。|
| check-single-streams | REDIS_EXPORTER_CHECK_SINGLE_STREAMS | 要导出 streams、groups 和 consumers 信息的 streams 的逗号分隔列表。直接查找，不使用任何 glob 模式匹配。如果不需要 glob 模式匹配请使用此选项；它比 `check-streams` 更快。|
| streams-exclude-consumer-metrics | REDIS_EXPORTER_STREAMS_EXCLUDE_CONSUMER_METRICS | 不收集 streams 的每个消费者指标（减少指标数量和基数）|
| check-keys-batch-size | REDIS_EXPORTER_CHECK_KEYS_BATCH_SIZE | 每次执行中要处理的大致键数量。这基本上是 SCAN 命令中的 COUNT 选项，参见 [COUNT 选项](https://valkey.io/commands/scan#the-count-option)。较大的值加速扫描。但 Redis 是单线程应用，巨大的 `COUNT` 可能影响生产环境。|
| count-keys | REDIS_EXPORTER_COUNT_KEYS | 要计数的模式的逗号分隔列表，例如：`db3=sessions:*` 将计数 db `3` 中所有前缀为 `sessions:` 的键。如果省略 db，默认为 `0`。警告：导出器运行 SCAN 来计数键，在大型数据库上可能性能不佳。|
| script | REDIS_EXPORTER_SCRIPT | 用于收集额外指标的 Redis Lua 脚本路径的逗号分隔列表。|
| debug | REDIS_EXPORTER_DEBUG | 详细调试输出 |
| log-level | REDIS_EXPORTER_LOG_LEVEL | 设置日志级别 |
| log-format | REDIS_EXPORTER_LOG_FORMAT | 日志格式，有效选项为 `txt`（默认）和 `json`。|
| namespace | REDIS_EXPORTER_NAMESPACE | 指标的命名空间，默认为 `redis`。|
| connection-timeout | REDIS_EXPORTER_CONNECTION_TIMEOUT | 连接 Redis 实例的超时时间，默认为 "15s"（Go 持续时间格式）|
| web.listen-address | REDIS_EXPORTER_WEB_LISTEN_ADDRESS | Web 界面和遥测的监听地址，默认为 `0.0.0.0:9121`。|
| web.telemetry-path | REDIS_EXPORTER_WEB_TELEMETRY_PATH | 暴露指标的路径，默认为 `/metrics`。|
| redis-only-metrics | REDIS_EXPORTER_REDIS_ONLY_METRICS | 是否只导出 Redis 指标（省略 Go 进程+运行时指标），默认为 false。|
| include-config-metrics | REDIS_EXPORTER_INCL_CONFIG_METRICS | 是否将所有配置设置作为指标包含，默认为 false。|
| include-system-metrics | REDIS_EXPORTER_INCL_SYSTEM_METRICS | 是否包含系统指标如 `total_system_memory_bytes`，默认为 false。|
| is-tile38 | REDIS_EXPORTER_IS_TILE38 | 是否抓取 Tile38 特定指标，默认为 false。|
| is-cluster | REDIS_EXPORTER_IS_CLUSTER | 是否为 Redis 集群（如果需要在 Redis 集群上获取键级别数据，请启用此选项）。|
| export-client-list | REDIS_EXPORTER_EXPORT_CLIENT_LIST | 是否抓取客户端列表特定指标，默认为 false。|
| skip-tls-verification | REDIS_EXPORTER_SKIP_TLS_VERIFICATION | 导出器连接 Redis 实例时是否跳过 TLS 验证 |
| tls-client-key-file | REDIS_EXPORTER_TLS_CLIENT_KEY_FILE | 如果服务器需要 TLS 客户端认证，客户端密钥文件名（包括完整路径）|
| tls-client-cert-file | REDIS_EXPORTER_TLS_CLIENT_CERT_FILE | 如果服务器需要 TLS 客户端认证，客户端证书文件名（包括完整路径）|
| tls-ca-cert-file | REDIS_EXPORTER_TLS_CA_CERT_FILE | 如果服务器需要 TLS 客户端认证，CA 证书文件名（包括完整路径）|
| set-client-name | REDIS_EXPORTER_SET_CLIENT_NAME | 是否将客户端名称设置为 redis_exporter，默认为 true。|
| check-key-groups | REDIS_EXPORTER_CHECK_KEY_GROUPS | 用于将键分类到组的 [LUA 正则表达式](https://www.lua.org/pil/20.1.html) 的逗号分隔列表。正则表达式按指定顺序应用于各个键，组名由第一个匹配键的正则表达式的所有捕获组连接生成。如果没有指定的正则表达式匹配键，该键将在 `unclassified` 组下跟踪。|
| max-distinct-key-groups | REDIS_EXPORTER_MAX_DISTINCT_KEY_GROUPS | 每个 Redis 数据库可以独立跟踪的不同键组的最大数量。如果超过，只有在限制内内存消耗最高的键组将被单独跟踪，所有剩余的键组将在单个 `overflow` 键组下报告。|
| basic-auth-username | REDIS_EXPORTER_BASIC_AUTH_USERNAME | redis exporter 的 Basic 认证用户名，需要与 basic-auth-password 一起设置才能生效 |
| basic-auth-password | REDIS_EXPORTER_BASIC_AUTH_PASSWORD | redis exporter 的 Basic 认证密码，需要与 basic-auth-username 一起设置才能生效，与 `basic-auth-hash-password` 冲突。|

Redis 实例地址可以是 tcp 地址：`redis://localhost:6379`、`redis.example.com:6379` 或例如 unix 套接字：`unix:///tmp/redis.sock`。\
通过使用 `rediss://` 模式支持 SSL，例如：`rediss://azure-ssl-enabled-host.redis.cache.windows.net:6380`（注意，当连接到非标准 6379 端口时需要指定端口，例如 Azure Redis 实例）。

命令行设置优先于环境变量提供的任何配置。

### Redis 认证

如果您的 Redis 实例需要认证，有几种方法可以提供用户名（Redis 6.x 的 ACL 中新增）和密码。

您可以在地址中提供用户名和密码，请参阅 `redis://` 模式的 [官方文档](https://www.iana.org/assignments/uri-schemes/prov/redis)。
您可以设置 `-redis.password-file=sample-pwd-file.json` 来指定密码文件，无论您使用 `/scrape` 端点抓取多个实例还是使用正常的 `/metrics` 端点抓取单个实例，它都会在导出器连接 Redis 实例时使用。
它仅在 `redis.password == ""` 时生效。请参阅 [contrib/sample-pwd-file.json](contrib/sample-pwd-file.json) 获取工作示例，并确保始终在密码文件条目中包含 `redis://`。

包含密码的 URI 示例：`redis://<<username (可选)>>:<<PASSWORD>>@<<HOSTNAME>>:<<PORT>>`

或者，您可以使用 `--redis.user` 和 `--redis.password` 直接向 redis_exporter 提供用户名和/或密码。

如果您想为 redis_exporter 使用专用的 Redis 用户（而不是默认用户），则需要为该用户启用一系列命令。
您可以使用以下 Redis 命令设置用户，只需将 `<<<USERNAME>>>` 和 `<<<PASSWORD>>>` 替换为您想要的值。

```
ACL SETUSER <<<USERNAME>>> -@all +@connection +memory -readonly +strlen +config|get +xinfo +pfcount -quit +zcard +type +xlen -readwrite -command +client -wait +scard +llen +hlen +get +eval +slowlog +cluster|info +cluster|slots +cluster|nodes -hello -echo +info +latency +scan -reset -auth -asking ><<<PASSWORD>>>
```

对于监控 Sentinel 节点，您可以使用以下命令设置正确的 ACL：

```
ACL SETUSER <<<USERNAME>>> -@all +@connection -command +client -hello +info -auth +sentinel|masters +sentinel|replicas +sentinel|slaves +sentinel|sentinels +sentinel|ckquorum ><<<PASSWORD>>>
```

### 通过 Docker 运行

最新版本自动发布到 [GitHub Container Registry (ghcr.io)](https://github.com/kevin197011/redis_exporter/pkgs/container/redis_exporter)

您可以这样运行：

```sh
docker run -d --name redis_exporter -p 9121:9121 ghcr.io/kevin197011/redis_exporter:latest
```

#### 使用环境变量配置

所有命令行参数都可以通过环境变量配置。如果 Redis 需要认证，可以通过 `REDIS_PASSWORD` 环境变量注入密码：

```sh
docker run -d --name redis_exporter -p 9121:9121 \
  -e REDIS_ADDR=redis://redis-server:6379 \
  -e REDIS_PASSWORD=your_password \
  ghcr.io/kevin197011/redis_exporter:latest
```

> **注意**：`REDIS_PASSWORD` 环境变量可选，不设置或为空时默认无密码连接。

#### Docker Compose 示例

```yaml
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD:-}
    ports:
      - "6379:6379"

  redis_exporter:
    image: ghcr.io/kevin197011/redis_exporter:latest
    ports:
      - "9121:9121"
    environment:
      REDIS_ADDR: redis://redis:6379
      REDIS_PASSWORD: ${REDIS_PASSWORD:-}  # 可选，不设置则无密码
    depends_on:
      - redis
```

使用方式：

```sh
# 无密码启动
docker-compose up -d

# 有密码启动
REDIS_PASSWORD=mysecretpassword docker-compose up -d
```

`latest` docker 镜像只包含导出器二进制文件。
如果出于调试目的，您需要在有 shell 的镜像中运行导出器，可以运行 `alpine` 镜像：

```sh
docker run -d --name redis_exporter -p 9121:9121 ghcr.io/kevin197011/redis_exporter:latest-alpine
```

如果您尝试访问在主机节点上运行的 Redis 实例，需要添加 `--network host` 以便 redis_exporter 容器可以访问它：

```sh
docker run -d --name redis_exporter --network host ghcr.io/kevin197011/redis_exporter:latest
```

### 完整监控栈部署（Docker Compose）

本项目提供完整的 Docker Compose 配置，包含 Redis、Exporter、Prometheus 和 Grafana：

```bash
# Redis Cluster 监控（3主3从集群）
docker-compose -f docker-compose-cluster.yml up -d

# Redis 单实例监控
docker-compose -f docker-compose-standalone.yml up -d

# Redis 主从复制监控
docker-compose -f docker-compose-replication.yml up -d
```

配置文件说明：

| 文件 | 说明 |
|------|------|
| `docker-compose-cluster.yml` | Redis Cluster + Exporter + Prometheus + Grafana |
| `docker-compose-standalone.yml` | 单实例 Redis + 完整监控栈 |
| `docker-compose-replication.yml` | 主从复制 + 完整监控栈 |
| `docker-compose-prd.yml` | 生产环境仅部署 Exporter |

访问地址：
- Grafana: http://localhost:3000 (admin/admin123)
- Prometheus: http://localhost:9090
- Redis Exporter: http://localhost:9121/metrics

### 在 Kubernetes 上运行

#### Sidecar 模式

[这里](contrib/k8s-redis-and-exporter-deployment.yaml) 是如何将 redis_exporter 作为 sidecar 部署到 Redis 实例的 Kubernetes 部署配置示例。

#### 集群监控模式（推荐）

对于 Redis Cluster（如 StatefulSet 部署的 redis-cluster-0 ~ redis-cluster-5），使用独立 Exporter + ServiceMonitor：

```bash
# 部署 Exporter 和 ServiceMonitor
kubectl apply -f contrib/k8s-redis-cluster-exporter.yaml
```

配置文件说明：

| 文件 | 说明 |
|------|------|
| `contrib/k8s-redis-cluster-exporter.yaml` | Exporter Deployment + Service + ServiceMonitor |
| `contrib/k8s-prometheus-scrape-config.yaml` | Prometheus 抓取配置（支持静态配置和自动发现） |

**自动发现方式**：
1. **静态配置**：在 `scrape_configs` 中列出所有 Redis 节点
2. **Pod 自动发现**：通过 `kubernetes_sd_configs` 的 pod 角色自动发现
3. **Endpoints 自动发现**：通过 Headless Service 的 endpoints 自动发现

**project 标签**：所有指标都带有 `project` 标签，方便在 Grafana 中按项目过滤不同的 Redis 集群。

### Tile38

[Tile38](https://tile38.com) 现在原生支持 Prometheus 导出服务器指标和对象、字符串等数量的基本统计。
您也可以使用 redis_exporter 导出 Tile38 指标，特别是通过使用 Lua 脚本或 `-check-keys` 参数获取更高级的指标。\
要启用 Tile38 支持，请使用 `--is-tile38=true` 运行导出器。

## 导出的内容

大多数来自 INFO 命令的项目都被导出，详情请参阅 [文档](https://valkey.io/commands/info)。\
此外，每个数据库都有总键数、过期键数和数据库中键的平均 TTL 的指标。\
您还可以通过使用 `-check-keys`（或相关）参数导出键的值。导出器还将导出键的大小（或根据数据类型的长度）。
这可用于导出（排序）集合、哈希、列表、流等中的元素数量。
如果键是字符串格式并且与 `--check-keys`（或相关）匹配，则其字符串值将作为 `key_value_as_string` 指标中的标签导出。

如果您需要自定义指标收集，可以使用 `-script` 参数提供 [Redis Lua 脚本](https://valkey.io/commands/eval) 路径的逗号分隔列表。如果只传递一个脚本，可以省略逗号。示例可以在 [contrib 文件夹](./contrib/sample_collect_script.lua) 中找到。

### redis_memory_max_bytes 指标

指标 `redis_memory_max_bytes` 将显示 Redis 可以使用的最大字节数。\
如果没有为您抓取的 Redis 实例设置内存限制（这是 Redis 的默认设置），则为零。\
您可以通过检查指标 `redis_config_maxmemory` 是否为零，或通过 redis-cli 连接到 Redis 实例并运行命令 `CONFIG GET MAXMEMORY` 来确认。

## 外观展示

示例 [Grafana](http://grafana.org/) 截图：
![redis_exporter_screen_01](https://cloud.githubusercontent.com/assets/1222339/19412031/897549c6-92da-11e6-84a0-b091f9deb81d.png)

![redis_exporter_screen_02](https://cloud.githubusercontent.com/assets/1222339/19412041/dee6d7bc-92da-11e6-84f8-610c025d6182.png)

### Grafana 仪表板

本项目提供两套开箱即用的 Grafana 仪表板：

| 仪表板 | 适用场景 | 文件位置 |
|--------|---------|---------|
| Redis Cluster Dashboard | Redis 集群（Cluster 模式） | [contrib/grafana/dashboards/redis-cluster-dashboard.json](contrib/grafana/dashboards/redis-cluster-dashboard.json) |
| Redis Standalone Dashboard | 单实例或主从架构 | [contrib/grafana/dashboards/redis-standalone-dashboard.json](contrib/grafana/dashboards/redis-standalone-dashboard.json) |

**仪表板特性**：
- 支持多数据源切换
- 支持 `project` 标签过滤不同项目/集群
- 支持 `instance` 多选查看多节点
- 集群仪表板自动过滤包含 `cluster` 的项目
- 单实例仪表板自动过滤包含 `standalone` 的项目

**监控面板包括**：
- 📊 实例可用性 / 连接数
- 💾 内存使用 / 碎片率
- 📈 命令执行次数 / 时长
- 💽 RDB/AOF 持久化状态
- 🔗 主从复制状态
- 🎯 集群 Slots 健康度（仅集群版）
- 📊 缓存命中率趋势

更多仪表板可在 [grafana.com](https://grafana.com/grafana/dashboards/763-redis-dashboard-for-prometheus-redis-exporter-1-x/) 获取。

### 同时查看多个 Redis

如果运行 [Redis Sentinel](https://redis.io/topics/sentinel)，可能希望同时查看各个集群成员的指标。因此，仪表板的下拉菜单是多值类型，允许选择多个 Redis。请注意有一个警告；顶部的单一统计面板即 `uptime`、`total memory use` 和 `clients` 在查看多个 Redis 时不起作用。

## 使用 mixin

在 [redis-mixin](contrib/redis-mixin/) 中有一组示例规则、告警和仪表板

mixin 包括：

### 告警（26 条规则）
- **可用性**: RedisDown, RedisTooManyConnections, RedisRejectedConnections
- **内存**: RedisOutOfMemory, RedisMemoryFragmentationHigh, RedisEvictingKeys
- **集群**: RedisClusterSlotFail, RedisClusterSlotPfail, RedisClusterStateNotOk, RedisClusterSlotsIncomplete, RedisClusterSlotsNotOk, RedisClusterNodeDown, RedisClusterTooFewNodes, RedisClusterSizeChanged, RedisClusterMessageStalled, RedisClusterMessageReceiveStalled
- **复制**: RedisReplicationBroken, RedisReplicationLag
- **持久化**: RedisRdbLastSaveTooOld, RedisRdbBgsaveFailed, RedisAofRewriteFailed
- **队列监控**: RedisQueueBacklog, RedisQueueBacklogCritical, RedisQueueGrowing
- **热键监控**: RedisHotkeyDetected, RedisLargeKeyDetected

### Recording Rules（14 条规则）
预计算的指标以获得更好的查询性能：
- `redis_cluster:slots_health_ratio` - 集群 slots 健康百分比
- `redis_cluster:is_healthy` - 整体集群健康状态 (0/1)
- `redis:memory_used_ratio` - 内存使用百分比
- `redis:connections_used_ratio` - 连接使用百分比
- `redis:keyspace_hit_ratio` - 缓存命中率
- `redis:commands_per_second` - 命令吞吐量
- 更多...

### 配置
所有阈值都可以在 `contrib/redis-mixin/config.libsonnet` 中配置：

```jsonnet
{
  _config+:: {
    redisExporterSelector: 'job="redis"',
    redisConnectionsThreshold: '100',
    redisClusterMinNodes: '6',
    redisReplicationLagThreshold: '30',
    redisQueueBacklogThreshold: '1000',
    redisHotkeyThreshold: '5',
    // ... 更多选项
  },
}
```

### 构建 mixin
```bash
cd contrib/redis-mixin
make deps   # 安装依赖
make build  # 生成 alerts.yaml、rules.yaml 和仪表板
```

## 按键组聚合内存使用

当单个 Redis 实例用于多种目的时，能够查看不同使用场景中 Redis 内存的消耗情况非常有用。当没有驱逐策略的 Redis 实例内存不足时，这尤其重要，因为我们想要确定是某些应用程序行为异常（例如没有删除不再使用的键）还是 Redis 实例需要扩展以处理增加的资源需求。幸运的是，大多数使用 Redis 的应用程序会为与其特定目的相关的键采用某种命名约定，如（层次化的）命名空间前缀，可以利用 redis_exporter 的 check-keys、check-single-keys 和 count-keys 参数来显示特定场景的内存使用指标。*按键组聚合内存使用* 更进一步，利用 Redis LUA 脚本支持的灵活性，通过用户定义的 [LUA 正则表达式](https://www.lua.org/pil/20.1.html) 列表将 Redis 实例上的所有键分类到组中，以便内存使用指标可以聚合到易于识别的组中。

要启用按键组聚合内存使用，只需通过 `check-key-groups` redis_exporter 参数指定一个非空的逗号分隔的 LUA 正则表达式列表。在每次按键组聚合内存指标时，redis_exporter 将为每个 Redis 数据库设置一个 `SCAN` 游标，通过 LUA 脚本分批处理。然后同一个 LUA 脚本逐键处理每个键批次，如下所示：

  1. 调用 `MEMORY USAGE` 命令来收集每个键的内存使用情况
  2. 指定的 LUA 正则表达式按指定顺序应用于每个键，给定键所属的组名将由第一个匹配该键的正则表达式的所有捕获组连接得出。例如，将正则表达式 `^(.*)_[^_]+$` 应用于键 `key_exp_Nick` 将产生组名 `key_exp`。如果没有指定的正则表达式匹配键，该键将被分配到 `unclassified` 组

一旦键被分类，相应组的内存使用量和键计数器将在本地 LUA 表中递增。当批次中的所有键都处理完毕后，这个聚合的指标表将与下一个 `SCAN` 游标位置一起返回给 redis_exporter，redis_exporter 可以将所有批次的数据聚合到一个分组内存使用指标的单一表中，供 Prometheus 指标抓取器使用。

按键组聚合时会暴露以下额外指标：

| 名称 | 标签 | 描述 |
|------|------|------|
| redis_key_group_count | db,key_group | 键组中的键数量 |
| redis_key_group_memory_usage_bytes | db,key_group | 键组的内存使用量 |
| redis_number_of_distinct_key_groups | db | 当 `overflow` 组完全展开时 Redis 数据库中不同键组的数量 |
| redis_last_key_groups_scrape_duration_milliseconds | | 最后一次按键组聚合内存使用的持续时间（毫秒）|

## 队列长度监控

有两种方法监控队列长度（List、Stream、Sorted Set）：

### 方法 1：使用内置参数（推荐用于固定队列）

```bash
# 直接监控特定队列（最快，不需要 SCAN）
./redis_exporter --check-single-keys="db0=queue:orders,db0=queue:emails,db0=celery"

# 监控匹配模式的队列（使用 SCAN）
./redis_exporter --check-keys="db0=queue:*,db0=bull:*"
```

这将导出 `redis_key_size{db, key}` 指标，其中包含队列长度：
- 对于 List：使用 `LLEN`
- 对于 Stream：使用 `XLEN`
- 对于 Sorted Set：使用 `ZCARD`
- 对于 Hash：使用 `HLEN`

### 方法 2：使用 Lua 脚本（推荐用于动态队列）

对于有很多动态队列的场景，使用提供的 Lua 脚本：

```bash
./redis_exporter --script=contrib/collect_queue_length.lua
```

该脚本自动扫描常见的队列前缀（`queue:`、`celery:`、`bull:`、`sidekiq:`、`resque:`）并通过 `redis_script_values{key}` 导出指标。

您可以自定义脚本以添加自己的队列前缀或特定队列名称。

## Key 热点检测

要检测热点 key（高访问频率）或大 key（高内存使用），使用热点检测脚本：

```bash
./redis_exporter --script=contrib/collect_key_hotspot.lua
```

### 导出的指标

| 指标 | 描述 |
|------|------|
| `redis_script_values{key="hotkey_freq_<keyname>"}` | 热点 key 的访问频率（需要 LFU 策略）|
| `redis_script_values{key="hotkey_memory_bytes_<keyname>"}` | 热点 key 的内存使用量 |
| `redis_script_values{key="hotkey_detected_total"}` | 检测到的热点 key 总数 |
| `redis_script_values{key="large_key_count"}` | 超过内存阈值的 key 数量 |
| `redis_script_values{key="lfu_policy_enabled"}` | LFU 策略是否启用 (1/0) |

### 启用 LFU 以获得更好的热点检测

为了更准确地检测热点，在 Redis 中启用 LFU（最少使用）驱逐策略：

```bash
redis-cli CONFIG SET maxmemory-policy allkeys-lfu
```

当启用 LFU 时，脚本使用 `OBJECT FREQ` 来获取键的实际访问频率。没有 LFU 时，脚本仅回退到基于内存的检测。

### 配置脚本

编辑 `contrib/collect_key_hotspot.lua` 以自定义：
- `key_prefixes`：要扫描热点的键前缀
- `top_n`：要导出的前 N 个热点键数量（默认：10）
- `memory_threshold`：大键检测的内存阈值（字节）（默认：1MB）

## 开发

测试需要各种真实的 Redis 实例，不仅用于验证导出器的正确性，还用于与旧版本 Redis 以及 KeyDB 或 Tile38 等类 Redis 系统的兼容性。\
[docker-compose.yml](docker-compose.yml) 文件包含所需一切的服务定义。\
您可以先通过运行 `make docker-env-up` 启动 Redis 测试实例，然后每次想运行测试时，可以运行 `make docker-test`。这将把当前目录（包含 .go 源文件）挂载到 docker 容器中并启动测试。\
测试完成后，您可以通过运行 `make docker-env-down` 关闭堆栈。\
或者您可以通过运行 `make docker-all` 一次性启动堆栈、运行测试、然后关闭堆栈。

***注意：** 使用持久测试环境时，测试初始化可能导致意外结果。当 `make docker-env-up` 执行一次而 `make docker-test` 不断运行或在执行期间停止时，数据库中的键数量会变化，这可能导致测试意外失败。作为解决方法，请定期使用 `make docker-env-down` 进行清理。*

## 社区贡献

如果您有更多建议、问题或关于添加什么的想法，请开一个 issue 或 PR。

