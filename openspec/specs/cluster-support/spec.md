# Cluster Support

## Purpose

Redis Exporter 的集群支持能力：支持 Redis Cluster 和 Redis Sentinel 的监控和指标采集。系统能够采集集群状态指标、发现集群节点、监控 Sentinel 主从拓扑，并正确处理跨节点的键操作。

## Requirements

### Requirement: Redis Cluster 模式

系统 SHALL 支持 Redis Cluster 模式，能够正确采集集群状态指标并支持跨节点键操作。

#### Scenario: 启用集群模式

- **GIVEN** `--is-cluster=true`
- **WHEN** 连接到 Redis Cluster 节点
- **THEN** 系统:
  - 执行 CLUSTER INFO 命令采集集群状态指标
  - 使用集群感知连接执行键检查操作
  - 启用 `/discover-cluster-nodes` 端点

#### Scenario: 集群指标采集

- **GIVEN** 连接到 Redis Cluster 节点
- **WHEN** INFO 显示 `cluster_enabled:1`
- **THEN** 系统导出:
  - `redis_cluster_messages_sent_total`
  - `redis_cluster_messages_received_total`

#### Scenario: 集群键操作

- **GIVEN** `--is-cluster=true` 且配置了 `--check-keys`
- **WHEN** 执行键检查
- **THEN** 系统使用集群连接，自动路由到正确的节点执行 SCAN 和 MEMORY USAGE

### Requirement: 集群节点发现

系统 SHALL 提供 HTTP 端点用于 Prometheus 动态发现集群所有节点。

#### Scenario: 发现集群节点

- **GIVEN** `--is-cluster=true`
- **WHEN** GET `/discover-cluster-nodes`
- **THEN** 系统返回 JSON 格式的节点列表:
  ```json
  [{
    "targets": ["redis://node1:6379", "redis://node2:6379"],
    "labels": {}
  }]
  ```

#### Scenario: TLS 集群节点发现

- **GIVEN** `--is-cluster=true` 且使用 `rediss://` 连接
- **WHEN** GET `/discover-cluster-nodes`
- **THEN** 返回的节点地址使用 `rediss://` 协议前缀

#### Scenario: 非集群模式访问发现端点

- **GIVEN** `--is-cluster=false`
- **WHEN** GET `/discover-cluster-nodes`
- **THEN** 返回 400 Bad Request

### Requirement: Redis Sentinel 监控

系统 SHALL 自动检测并采集 Redis Sentinel 实例的监控指标。

#### Scenario: Sentinel 指标采集

- **GIVEN** 连接到 Sentinel 实例 (INFO 包含 `# Sentinel` 部分)
- **WHEN** 执行指标采集
- **THEN** 系统导出:
  - `redis_sentinel_masters` - 监控的 master 数量
  - `redis_sentinel_tilt` - TILT 模式状态
  - `redis_sentinel_running_scripts`
  - `redis_sentinel_scripts_queue_length`
  - `redis_sentinel_simulate_failure_flags`

#### Scenario: Sentinel Master 详情

- **GIVEN** 连接到 Sentinel 实例
- **WHEN** 执行 SENTINEL MASTERS 命令
- **THEN** 系统为每个监控的 master 导出:
  - `redis_sentinel_master_status{master_name, master_address, master_status}`
  - `redis_sentinel_master_slaves{master_name, master_address}`
  - `redis_sentinel_master_sentinels{master_name, master_address}`
  - `redis_sentinel_master_ok_slaves{master_name, master_address}`
  - `redis_sentinel_master_ok_sentinels{master_name, master_address}`

#### Scenario: Sentinel ckquorum 检查

- **GIVEN** 连接到 Sentinel 实例
- **WHEN** 执行 SENTINEL CKQUORUM 命令
- **THEN** 系统导出:
  - `redis_sentinel_master_ckquorum_status{master_name, message}` - 仲裁状态

#### Scenario: Sentinel 配置指标

- **GIVEN** 连接到 Sentinel 实例
- **WHEN** 执行指标采集
- **THEN** 系统导出每个 master 的配置:
  - `redis_sentinel_master_setting_down_after_milliseconds`
  - `redis_sentinel_master_setting_failover_timeout`
  - `redis_sentinel_master_setting_parallel_syncs`
  - `redis_sentinel_master_setting_ckquorum`

### Requirement: 复制拓扑指标

系统 SHALL 导出主从复制拓扑相关指标。

#### Scenario: Slave 信息导出

- **GIVEN** 连接到 Redis slave 实例
- **WHEN** 解析 INFO replication 部分
- **THEN** 系统导出:
  - `redis_slave_info{master_host, master_port, read_only}`
  - `redis_slave_repl_offset{master_host, master_port}`
  - `redis_master_link_up{master_host, master_port}`
  - `redis_master_last_io_seconds_ago{master_host, master_port}`
  - `redis_master_sync_in_progress{master_host, master_port}`

#### Scenario: Master 连接的 Slave 指标

- **GIVEN** 连接到 Redis master 实例
- **WHEN** 解析 INFO replication 中的 slave 信息
- **THEN** 系统为每个 slave 导出:
  - `redis_connected_slave_offset_bytes{slave_ip, slave_port, slave_state}`
  - `redis_connected_slave_lag_seconds{slave_ip, slave_port, slave_state}`

### Requirement: 跳过 Master 键检查

系统 SHALL 支持在 master 节点上跳过键检查操作以减轻负载。

#### Scenario: 跳过 Master 键检查

- **GIVEN** `--skip-checkkeys-for-role-master=true`
- **AND** 连接到 master 节点
- **WHEN** 执行指标采集
- **THEN** 系统跳过 check-keys、check-streams、count-keys 等键操作

#### Scenario: Slave 节点正常采集

- **GIVEN** `--skip-checkkeys-for-role-master=true`
- **AND** 连接到 slave 节点
- **WHEN** 执行指标采集
- **THEN** 系统正常执行所有键检查操作

## Design Notes

### Prometheus 集群配置示例

```yaml
scrape_configs:
  - job_name: 'redis_exporter_cluster_nodes'
    http_sd_configs:
      - url: http://exporter:9121/discover-cluster-nodes
        refresh_interval: 10m
    metrics_path: /scrape
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: exporter:9121
```

### 实现位置

- 集群连接: `exporter/redis.go` - `connectToRedisCluster()`
- 集群节点获取: `exporter/nodes.go` - `getClusterNodes()`
- 集群发现端点: `exporter/http.go` - `discoverClusterNodesHandler()`
- Sentinel 指标: `exporter/sentinels.go` - `extractSentinelMetrics()`
- 复制信息解析: `exporter/info.go`

