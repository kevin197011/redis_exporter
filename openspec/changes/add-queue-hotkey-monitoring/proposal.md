# Change: 添加队列长度和 Key 热点监控脚本

## Why

用户需要监控：
1. 队列长度（List/Stream/ZSet）- 用于监控消息积压
2. Key 热点 - 用于发现高访问频率或大内存占用的 key

虽然 redis_exporter 已支持 `--check-single-keys` 用于基础队列监控，但对于大量动态队列和热点检测场景需要更灵活的 Lua 脚本方案。

## What Changes

- 新增 `contrib/collect_queue_length.lua` - 动态队列长度采集脚本
- 新增 `contrib/collect_key_hotspot.lua` - Key 热点检测脚本
- 新增对应的告警规则

## Impact

- Affected specs: key-analysis
- Affected code: `contrib/`

