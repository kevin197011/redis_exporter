## ADDED Requirements

### Requirement: 集群节点数量监控

系统 SHALL 监控集群已知节点数量变化，在节点异常减少时告警。

#### Scenario: 节点数量下降告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_known_nodes` 在 5 分钟内下降超过预期节点数
- **THEN** 触发 `RedisClusterNodeDown` 告警
- **AND** 严重级别为 warning

### Requirement: 集群 Slots 完整性监控

系统 SHALL 监控集群 slots 分配完整性，确保 16384 个 slots 全部被分配。

#### Scenario: Slots 未完全分配告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_slots_assigned` < 16384
- **THEN** 触发 `RedisClusterSlotsIncomplete` 告警
- **AND** 严重级别为 critical

### Requirement: 集群消息通信监控

系统 SHALL 监控集群节点间消息通信，在通信异常时告警。

#### Scenario: 消息发送停滞告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_messages_sent_total` 增长率为 0 超过 5 分钟
- **THEN** 触发 `RedisClusterMessageStalled` 告警
- **AND** 严重级别为 warning

### Requirement: Recording Rules 性能优化

系统 SHALL 提供 Recording rules 预计算集群健康度指标，优化查询性能。

#### Scenario: 预计算 Slots 健康率

- **GIVEN** Prometheus 配置了 recording rules
- **WHEN** 采集 Redis 集群指标
- **THEN** 自动计算并存储 `redis_cluster:slots_health_ratio` 指标
- **AND** 值为 slots_ok / slots_assigned

## MODIFIED Requirements

### Requirement: 集群 slots 健康度

系统 SHALL 导出 Redis Cluster slots 相关指标，并提供完善的告警规则覆盖 fail、pfail、state 异常等场景。

#### Scenario: Slots Fail 告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_slots_fail` > 0 持续 5 分钟
- **THEN** 触发 `RedisClusterSlotFail` 告警
- **AND** 严重级别为 warning

#### Scenario: Slots PFail 告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_slots_pfail` > 0 持续 5 分钟
- **THEN** 触发 `RedisClusterSlotPfail` 告警
- **AND** 严重级别为 warning

#### Scenario: 集群状态异常告警

- **GIVEN** Redis Cluster 正常运行
- **WHEN** `redis_cluster_state` == 0 持续 5 分钟
- **THEN** 触发 `RedisClusterStateNotOk` 告警
- **AND** 严重级别为 critical

