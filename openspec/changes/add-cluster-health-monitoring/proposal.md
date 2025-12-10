# Change: 增强 Redis Cluster 健康度监控

## Why

当前 redis_exporter 已采集 CLUSTER INFO 的所有指标，但 redis-mixin 的告警规则仅覆盖基础场景（slots fail/pfail、cluster state）。需要扩展更完善的集群健康度监控，包括：
- 节点数量异常告警
- Slots 分配完整性检查
- 集群消息通信异常检测
- Recording rules 提升查询性能

## What Changes

- 扩展 `contrib/redis-mixin/alerts/redis.libsonnet` 添加更多集群告警
- 新增 `contrib/redis-mixin/rules/redis.libsonnet` Recording rules
- 更新配置支持集群阈值自定义

## Impact

- Affected specs: cluster-support
- Affected code: `contrib/redis-mixin/`

