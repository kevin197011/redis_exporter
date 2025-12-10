# Lua Scripting

## Purpose

Redis Exporter 的 Lua 脚本扩展能力：支持执行自定义 Lua 脚本采集额外指标。系统允许用户编写 Lua 脚本在 Redis 服务器上执行，实现复杂的自定义指标计算和数据聚合。

## Requirements

### Requirement: 加载自定义脚本

系统 SHALL 支持加载并执行用户自定义的 Lua 脚本来采集额外指标。

#### Scenario: 配置脚本文件

- **GIVEN** `--script=/path/to/custom.lua`
- **WHEN** Exporter 启动
- **THEN** 系统加载脚本内容到内存

#### Scenario: 配置多个脚本

- **GIVEN** `--script=/path/to/script1.lua,/path/to/script2.lua`
- **WHEN** Exporter 启动
- **THEN** 系统加载所有脚本
- **AND** 每次指标采集时执行所有脚本

#### Scenario: 脚本文件不存在

- **GIVEN** 配置的脚本文件不存在
- **WHEN** Exporter 启动
- **THEN** 系统报错并退出

### Requirement: 脚本执行

系统 SHALL 在每次指标采集时执行加载的 Lua 脚本。

#### Scenario: 执行脚本

- **GIVEN** 配置了 Lua 脚本
- **WHEN** 执行指标采集
- **THEN** 系统使用 EVAL 命令在 Redis 上执行脚本
- **AND** 解析脚本返回值为指标

#### Scenario: 脚本执行结果

- **GIVEN** 脚本执行成功
- **WHEN** 解析返回值
- **THEN** 系统导出:
  - `redis_script_result{filename}` - 脚本执行状态 (1=成功)
  - `redis_script_values{key, filename}` - 脚本返回的键值对指标

### Requirement: 脚本返回格式

系统 SHALL 解析脚本返回的特定格式数据为 Prometheus 指标。

#### Scenario: 返回键值对

- **GIVEN** 脚本返回 `{"key1", value1, "key2", value2, ...}` 格式
- **WHEN** 解析返回值
- **THEN** 系统为每个键值对创建 `redis_script_values{key="key1", filename="script.lua"}` 指标
- **AND** 值为数值类型

#### Scenario: 返回单个值

- **GIVEN** 脚本返回单个数值
- **WHEN** 解析返回值
- **THEN** 系统创建 `redis_script_result{filename="script.lua"}` 指标

#### Scenario: 脚本返回错误

- **GIVEN** 脚本执行出错
- **WHEN** 解析返回值
- **THEN** 系统记录错误日志
- **AND** `redis_script_result{filename}` 值为 0

### Requirement: 示例脚本功能

系统 SHALL 提供示例脚本展示如何编写自定义指标采集脚本。

#### Scenario: 列表长度采集示例

- **GIVEN** 使用 `contrib/sample_collect_script.lua`
- **WHEN** 执行脚本
- **THEN** 脚本演示如何:
  - 扫描匹配特定模式的键
  - 获取列表长度
  - 返回聚合结果

#### Scenario: 列表增长监控示例

- **GIVEN** 使用 `contrib/collect_lists_length_growing.lua`
- **WHEN** 执行脚本
- **THEN** 脚本采集 Redis 列表的长度信息
- **AND** 可用于监控列表增长趋势

## Design Notes

### 脚本编写指南

Lua 脚本应返回一个包含键值对的数组：

```lua
-- 示例脚本
local result = {}

-- 获取某个键的值
local value = redis.call('GET', 'my_metric_key')
if value then
    table.insert(result, 'my_metric')
    table.insert(result, tonumber(value))
end

-- 统计某类键的数量
local keys = redis.call('KEYS', 'prefix:*')
table.insert(result, 'prefix_key_count')
table.insert(result, #keys)

return result
```

### 性能注意事项

- Lua 脚本在 Redis 服务器上执行，复杂脚本会阻塞其他操作
- 避免在脚本中使用 KEYS 命令扫描大量键
- 优先使用 SCAN 命令进行键遍历
- 脚本执行超时会导致指标采集失败

### 与 check-key-groups 的区别

| 特性 | Lua 脚本 | check-key-groups |
|------|----------|------------------|
| 灵活性 | 完全自定义 | 仅内存分组 |
| 复杂度 | 需编写脚本 | 仅配置正则 |
| 执行位置 | Redis 服务器 | Exporter + Redis |
| 用例 | 自定义指标计算 | 键分组统计 |

### 实现位置

- 脚本加载: `main.go` - `loadScripts()`
- 脚本执行: `exporter/lua.go` - `extractLuaScriptMetrics()`
- 示例脚本: `contrib/sample_collect_script.lua`, `contrib/collect_lists_length_growing.lua`

### 示例脚本位置

```
contrib/
├── sample_collect_script.lua        # 基础示例
└── collect_lists_length_growing.lua # 列表监控示例
```

