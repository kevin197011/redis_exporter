## ADDED Requirements

### Requirement: 动态队列长度监控

系统 SHALL 支持通过 Lua 脚本动态采集多个队列的长度指标。

#### Scenario: 按前缀采集队列长度

- **GIVEN** 配置了 `--script=contrib/collect_queue_length.lua`
- **WHEN** 执行指标采集
- **THEN** 系统扫描匹配前缀的 List/Stream/ZSet key
- **AND** 导出 `redis_script_values{key="queue_length_<keyname>"}` 指标

#### Scenario: 采集特定队列

- **GIVEN** 在脚本中配置了 `specific_queues` 列表
- **WHEN** 执行指标采集
- **THEN** 系统直接获取指定队列的长度
- **AND** 无需 SCAN 扫描

### Requirement: Key 热点检测

系统 SHALL 支持通过 Lua 脚本检测高访问频率或大内存占用的热点 key。

#### Scenario: LFU 策略热点检测

- **GIVEN** Redis 配置了 `maxmemory-policy` 为 `*lfu`
- **AND** 配置了 `--script=contrib/collect_key_hotspot.lua`
- **WHEN** 执行指标采集
- **THEN** 系统使用 `OBJECT FREQ` 获取 key 访问频率
- **AND** 导出 Top N 热点 key 的频率指标

#### Scenario: 大内存 Key 检测

- **GIVEN** 配置了 `--script=contrib/collect_key_hotspot.lua`
- **WHEN** 执行指标采集
- **THEN** 系统使用 `MEMORY USAGE` 获取 key 内存占用
- **AND** 导出超过阈值的大 key 指标

#### Scenario: 非 LFU 策略降级

- **GIVEN** Redis 未配置 LFU 策略
- **WHEN** 执行热点检测
- **THEN** 系统仅基于内存使用量检测大 key
- **AND** 导出 `lfu_policy_enabled=0` 指标

