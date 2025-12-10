# Key Analysis

## Purpose

Redis Exporter 的键分析能力：支持检查特定键的值、大小、内存使用，以及按模式统计键数量和内存分组。系统通过 SCAN、MEMORY USAGE、XINFO 等命令实现灵活的键级别监控和内存分析。

## Requirements

### Requirement: 键模式检查 (check-keys)

系统 SHALL 支持通过 SCAN 命令按模式匹配键，并导出匹配键的值、大小和内存使用指标。

#### Scenario: 配置键模式检查

- **GIVEN** `--check-keys=db0=user:*,db1=session:*`
- **WHEN** 执行指标采集
- **THEN** 系统使用 SCAN 命令在指定数据库中匹配键
- **AND** 为每个匹配的键导出指标

#### Scenario: 导出键指标

- **GIVEN** 配置了 check-keys 且匹配到键
- **WHEN** 导出指标
- **THEN** 系统导出:
  - `redis_key_size{db, key}` - 键的长度/大小（list长度、set基数等）
  - `redis_key_value{db, key}` - 数值类型键的值
  - `redis_key_memory_usage_bytes{db, key}` - 键的内存使用
  - `redis_key_value_as_string{db, key, val}` - 字符串值作为标签

#### Scenario: 批量扫描配置

- **GIVEN** `--check-keys-batch-size=5000`
- **WHEN** 执行 SCAN 命令
- **THEN** 系统使用 COUNT 5000 参数控制每批扫描数量

#### Scenario: 集群模式限制

- **GIVEN** `--is-cluster=true` 且配置了 `--check-keys`
- **WHEN** 执行键检查
- **THEN** 系统记录警告：check-keys 使用 SCAN，不能跨集群实例工作

### Requirement: 单键检查 (check-single-keys)

系统 SHALL 支持直接检查指定的单个键，无需 SCAN 扫描，性能更优。

#### Scenario: 配置单键检查

- **GIVEN** `--check-single-keys=db0=user_count,db1=active_sessions`
- **WHEN** 执行指标采集
- **THEN** 系统直接使用 GET/TYPE/MEMORY USAGE 命令获取键信息
- **AND** 无需执行 SCAN 扫描

#### Scenario: 单键不存在

- **GIVEN** 配置的单键不存在
- **WHEN** 执行指标采集
- **THEN** 系统跳过该键，不报错

### Requirement: 键计数 (count-keys)

系统 SHALL 支持按模式统计键数量。

#### Scenario: 配置键计数

- **GIVEN** `--count-keys=db0=sessions:*,db0=cache:*`
- **WHEN** 执行指标采集
- **THEN** 系统使用 SCAN 统计匹配模式的键数量
- **AND** 导出 `redis_keys_count{db, key}` 指标

#### Scenario: 大量键警告

- **GIVEN** 配置了 count-keys 匹配大量键
- **WHEN** 执行指标采集
- **THEN** 系统完成计数，但文档警告可能影响性能

### Requirement: Stream 检查 (check-streams)

系统 SHALL 支持检查 Redis Stream 的详细信息，包括消费组和消费者状态。

#### Scenario: 配置 Stream 检查

- **GIVEN** `--check-streams=db0=events:*`
- **WHEN** 执行指标采集
- **THEN** 系统使用 SCAN 匹配 Stream 键
- **AND** 使用 XINFO STREAM 获取详情

#### Scenario: 导出 Stream 指标

- **GIVEN** 匹配到 Stream 键
- **WHEN** 导出指标
- **THEN** 系统导出:
  - `redis_stream_length{db, stream}` - Stream 元素数量
  - `redis_stream_groups{db, stream}` - 消费组数量
  - `redis_stream_radix_tree_keys{db, stream}`
  - `redis_stream_radix_tree_nodes{db, stream}`
  - `redis_stream_first_entry_id{db, stream}`
  - `redis_stream_last_entry_id{db, stream}`
  - `redis_stream_last_generated_id{db, stream}`
  - `redis_stream_max_deleted_entry_id{db, stream}`

#### Scenario: 导出消费组指标

- **GIVEN** Stream 有消费组
- **WHEN** 导出指标
- **THEN** 系统导出:
  - `redis_stream_group_consumers{db, stream, group}`
  - `redis_stream_group_messages_pending{db, stream, group}`
  - `redis_stream_group_last_delivered_id{db, stream, group}`
  - `redis_stream_group_entries_read{db, stream, group}`
  - `redis_stream_group_lag{db, stream, group}`

#### Scenario: 导出消费者指标

- **GIVEN** 消费组有消费者
- **AND** `--streams-exclude-consumer-metrics=false` (默认)
- **WHEN** 导出指标
- **THEN** 系统导出:
  - `redis_stream_group_consumer_messages_pending{db, stream, group, consumer}`
  - `redis_stream_group_consumer_idle_seconds{db, stream, group, consumer}`

#### Scenario: 排除消费者指标

- **GIVEN** `--streams-exclude-consumer-metrics=true`
- **WHEN** 导出指标
- **THEN** 系统不导出消费者级别指标，减少指标基数

### Requirement: 单 Stream 检查 (check-single-streams)

系统 SHALL 支持直接检查指定的单个 Stream，无需 SCAN 扫描。

#### Scenario: 配置单 Stream 检查

- **GIVEN** `--check-single-streams=db0=events,db0=logs`
- **WHEN** 执行指标采集
- **THEN** 系统直接查询指定 Stream 信息
- **AND** 无需执行 SCAN 扫描

### Requirement: 键分组内存分析 (check-key-groups)

系统 SHALL 支持使用 LUA 正则表达式将键分组，并聚合每组的内存使用统计。

#### Scenario: 配置键分组

- **GIVEN** `--check-key-groups=^(user)_[^_]+$,^(session):[^:]+$`
- **WHEN** 执行指标采集
- **THEN** 系统:
  - 使用 SCAN 遍历所有键
  - 应用 LUA 正则表达式分类键
  - 聚合每组的内存使用和键数量

#### Scenario: 导出键分组指标

- **GIVEN** 配置了键分组
- **WHEN** 导出指标
- **THEN** 系统导出:
  - `redis_key_group_count{db, key_group}` - 每组键数量
  - `redis_key_group_memory_usage_bytes{db, key_group}` - 每组内存使用
  - `redis_number_of_distinct_key_groups{db}` - 不同组数量
  - `redis_last_key_groups_scrape_duration_milliseconds` - 分组分析耗时

#### Scenario: 未分类的键

- **GIVEN** 某些键不匹配任何正则表达式
- **WHEN** 导出指标
- **THEN** 这些键被归入 `unclassified` 分组

#### Scenario: 限制分组数量

- **GIVEN** `--max-distinct-key-groups=100` (默认)
- **WHEN** 实际分组数量超过限制
- **THEN** 系统只保留内存使用最高的 100 个分组
- **AND** 其余分组聚合到 `overflow` 分组

### Requirement: 禁用键值导出

系统 SHALL 支持禁用将键值作为指标标签导出，以保护敏感数据。

#### Scenario: 禁用键值导出

- **GIVEN** `--disable-exporting-key-values=true`
- **WHEN** 执行键检查
- **THEN** 系统不导出 `redis_key_value_as_string` 指标
- **AND** 不将键值作为标签导出

## Design Notes

### 性能考虑

- `check-keys` 和 `count-keys` 使用 SCAN 命令，大量键会影响性能
- `check-single-keys` 和 `check-single-streams` 直接查询，性能更好
- `check-keys-batch-size` 控制 SCAN COUNT，需平衡速度和 Redis 负载
- `check-key-groups` 需要遍历所有键，对大数据库影响显著

### 键参数格式

```
db<N>=<pattern>
```

- `db<N>` 可选，默认为 `db0`
- 多个模式用逗号分隔

示例:
- `user_count` → db0 的 user_count 键
- `db1=sessions:*` → db1 中匹配 sessions:* 的键
- `db0=a*,db1=b*` → db0 的 a* 和 db1 的 b*

### LUA 正则表达式

键分组使用 LUA 正则表达式，不是 PCRE：
- `^(.*)_[^_]+$` → 匹配 `prefix_suffix`，捕获组为 `prefix`
- 分组名称由所有捕获组连接而成
- 参考: https://www.lua.org/pil/20.1.html

### 实现位置

- 键检查: `exporter/keys.go` - `extractCheckKeyMetrics()`
- 键计数: `exporter/keys.go` - `extractCountKeysMetrics()`
- Stream 检查: `exporter/streams.go` - `extractStreamMetrics()`
- 键分组: `exporter/key_groups.go` - `extractKeyGroupMetrics()`

