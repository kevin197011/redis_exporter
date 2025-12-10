# Metrics Collection

## Purpose

Redis Exporter 的核心能力：从 Redis/Valkey 实例收集指标并以 Prometheus 格式导出。系统通过执行 Redis 命令（INFO、CONFIG、SLOWLOG 等）获取运行时数据，并转换为 Prometheus 指标格式供监控系统抓取。

## Requirements

### Requirement: INFO 命令指标采集

系统 SHALL 通过执行 Redis INFO 命令采集服务器、客户端、内存、持久化、复制、CPU 和统计等分类的指标。

#### Scenario: 成功采集 INFO ALL 指标

- **GIVEN** Redis 实例可达且响应正常
- **WHEN** Exporter 执行 `INFO ALL` 命令
- **THEN** 系统解析响应并生成相应的 Prometheus 指标
- **AND** 指标包含 server/clients/memory/persistence/stats/replication/cpu 等分类

#### Scenario: INFO ALL 不可用时降级

- **GIVEN** Redis 实例不支持 `INFO ALL`
- **WHEN** `INFO ALL` 命令失败
- **THEN** 系统降级执行 `INFO` 命令
- **AND** 仍然导出基础指标

### Requirement: CONFIG 指标采集

系统 SHALL 通过 CONFIG GET 命令采集 Redis 配置相关指标，并支持跳过或脱敏敏感配置。

#### Scenario: 采集配置指标

- **GIVEN** `--include-config-metrics=true`
- **WHEN** 执行 CONFIG GET * 命令
- **THEN** 系统导出配置键值对为 `redis_config_key_value` 和 `redis_config_value` 指标

#### Scenario: 脱敏敏感配置

- **GIVEN** `--redact-config-metrics=true` (默认)
- **WHEN** 配置包含 masterauth/requirepass/tls-key-file-pass 等敏感字段
- **THEN** 系统不导出这些敏感配置的值

#### Scenario: 跳过 CONFIG 采集

- **GIVEN** `--config-command=-`
- **WHEN** 执行指标采集
- **THEN** 系统跳过 CONFIG GET 命令，不采集配置指标

### Requirement: 数据库键统计

系统 SHALL 为每个数据库导出键数量、过期键数量和平均 TTL 指标。

#### Scenario: 导出数据库键指标

- **GIVEN** Redis 实例有多个数据库包含数据
- **WHEN** 解析 INFO keyspace 部分
- **THEN** 系统导出 `redis_db_keys`、`redis_db_keys_expiring` 和 `redis_db_avg_ttl_seconds` 指标
- **AND** 每个指标包含 `db` 标签标识数据库编号

#### Scenario: 空数据库指标控制

- **GIVEN** `--include-metrics-for-empty-databases=false`
- **WHEN** 某数据库为空
- **THEN** 系统不为该数据库生成键统计指标

### Requirement: 版本兼容性

系统 SHALL 支持 Redis 2.x 到 7.x 各版本，并根据版本差异处理指标名称变化。

#### Scenario: Redis 5.x 指标名称变化

- **GIVEN** 连接到 Redis 5.x 实例
- **WHEN** 采集客户端缓冲区指标
- **THEN** 系统正确映射 `client_recent_max_output_buffer` 到 `redis_client_recent_max_output_buffer_bytes`

#### Scenario: Redis 7.0 新增指标

- **GIVEN** 连接到 Redis 7.0+ 实例
- **WHEN** 采集指标
- **THEN** 系统导出 Redis 7.0 新增指标如 `eventloop_cycles_total`、`evicted_clients_total` 等

### Requirement: Exporter 自身指标

系统 SHALL 导出 Exporter 自身的运行指标，包括抓取次数、抓取耗时、错误状态等。

#### Scenario: 导出 Exporter 指标

- **WHEN** 访问 /metrics 端点
- **THEN** 系统导出以下指标:
  - `redis_exporter_scrapes_total` - 总抓取次数
  - `redis_exporter_scrape_duration_seconds` - 抓取耗时摘要
  - `redis_exporter_last_scrape_error` - 最后一次抓取错误状态
  - `redis_exporter_last_scrape_connect_time_seconds` - 连接耗时
  - `redis_exporter_build_info` - 构建信息

#### Scenario: PING 延迟指标

- **GIVEN** `--ping-on-connect=true`
- **WHEN** 连接到 Redis 实例后
- **THEN** 系统执行 PING 命令并导出 `redis_exporter_last_scrape_ping_time_seconds`

### Requirement: 命令统计指标

系统 SHALL 导出每个 Redis 命令的调用统计，包括调用次数和耗时。

#### Scenario: 导出命令统计

- **GIVEN** INFO commandstats 部分可用
- **WHEN** 解析命令统计
- **THEN** 系统为每个命令导出:
  - `redis_commands_total{cmd="get"}` - 调用次数
  - `redis_commands_duration_seconds_total{cmd="get"}` - 总耗时
  - `redis_commands_failed_calls_total{cmd="get"}` - 失败次数

### Requirement: 错误统计指标

系统 SHALL 导出按错误类型分类的错误统计指标。

#### Scenario: 导出错误统计

- **GIVEN** INFO errorstats 部分可用 (Redis 6.2+)
- **WHEN** 解析错误统计
- **THEN** 系统导出 `redis_errors_total{err="ERR"}` 格式的指标

### Requirement: 延迟直方图指标

系统 SHALL 支持采集 Redis 7.0+ 的 LATENCY HISTOGRAM 命令输出。

#### Scenario: 采集延迟直方图

- **GIVEN** Redis 7.0+ 实例
- **AND** `--exclude-latency-histogram-metrics=false` (默认)
- **WHEN** 执行指标采集
- **THEN** 系统执行 LATENCY HISTOGRAM 命令
- **AND** 导出 `redis_commands_latencies_usec` 和 `redis_latency_percentiles_usec` 指标

#### Scenario: 跳过延迟直方图

- **GIVEN** `--exclude-latency-histogram-metrics=true`
- **WHEN** 执行指标采集
- **THEN** 系统不执行 LATENCY HISTOGRAM 命令

### Requirement: 慢查询日志指标

系统 SHALL 导出慢查询日志相关指标。

#### Scenario: 导出慢查询指标

- **WHEN** 执行 SLOWLOG 命令
- **THEN** 系统导出:
  - `redis_slowlog_length` - 慢查询日志条数
  - `redis_slowlog_last_id` - 最后一条慢查询 ID
  - `redis_last_slow_execution_duration_seconds` - 最后一条慢查询耗时

### Requirement: 系统指标

系统 SHALL 可选地导出系统级指标如总系统内存。

#### Scenario: 导出系统指标

- **GIVEN** `--include-system-metrics=true`
- **WHEN** 执行指标采集
- **THEN** 系统导出 `redis_total_system_memory_bytes` 指标

### Requirement: 指标命名空间

系统 SHALL 支持自定义指标命名空间前缀。

#### Scenario: 自定义命名空间

- **GIVEN** `--namespace=myredis`
- **WHEN** 导出指标
- **THEN** 所有指标使用 `myredis_` 前缀而非默认的 `redis_`

### Requirement: Go 运行时指标控制

系统 SHALL 支持控制是否导出 Go 运行时和进程指标。

#### Scenario: 仅导出 Redis 指标

- **GIVEN** `--redis-only-metrics=true`
- **WHEN** 访问 /metrics 端点
- **THEN** 系统仅导出 Redis 相关指标，不导出 Go 进程指标

#### Scenario: 包含 Go 运行时指标

- **GIVEN** `--include-go-runtime-metrics=true`
- **WHEN** 访问 /metrics 端点
- **THEN** 系统导出完整的 Go 运行时指标（GC、内存统计等）

## Design Notes

### 指标映射表

指标映射定义在 `exporter/exporter.go` 的 `metricMapGauges` 和 `metricMapCounters` 中：
- Gauges: 可增减的即时值（连接数、内存使用等）
- Counters: 只增不减的累计值（命令执行次数等）

### 实现位置

- 主要逻辑: `exporter/exporter.go` - `scrapeRedisHost()`
- INFO 解析: `exporter/info.go` - `extractInfoMetrics()`
- CONFIG 解析: `exporter/exporter.go` - `extractConfigMetrics()`
- 延迟指标: `exporter/latency.go` - `extractLatencyMetrics()`
- 慢查询: `exporter/slowlog.go` - `extractSlowLogMetrics()`

