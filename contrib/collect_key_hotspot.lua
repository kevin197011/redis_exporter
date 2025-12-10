-- Key Hotspot Collector Script
-- Key 热点采集脚本
-- Usage: --script=/path/to/collect_key_hotspot.lua
--
-- 注意：此脚本通过分析 Redis 内部统计来检测热点 key
-- 需要 Redis 4.0+ 支持 MEMORY USAGE 和 OBJECT FREQ 命令
--
-- 热点检测方法：
-- 1. OBJECT FREQ - 获取 LFU 访问频率（需要 maxmemory-policy 为 *lfu）
-- 2. MEMORY USAGE - 获取内存占用大小
-- 3. SCAN + 分析 - 扫描指定前缀的 key 并分析

local result = {}

-- ============================================
-- 配置区域
-- ============================================

-- 监控的 key 前缀（热点检测范围）
local key_prefixes = {
    "cache:",      -- 缓存 key
    "session:",    -- 会话 key
    "user:",       -- 用户相关
    "product:",    -- 产品相关
    "hot:",        -- 热点数据
}

-- Top N 热点 key 数量
local top_n = 10

-- 内存使用阈值（字节），超过此值的 key 会被标记
local memory_threshold = 1024 * 1024  -- 1MB

-- ============================================
-- 热点检测逻辑
-- ============================================

-- 存储热点候选
local hotspot_candidates = {}

-- 检查 Redis 是否支持 OBJECT FREQ（需要 LFU 策略）
local function check_lfu_support()
    local policy = redis.call("CONFIG", "GET", "maxmemory-policy")
    if policy and policy[2] then
        return string.find(policy[2], "lfu") ~= nil
    end
    return false
end

local lfu_enabled = check_lfu_support()

-- 扫描并分析热点 key
for _, prefix in ipairs(key_prefixes) do
    local cursor = "0"
    local max_iterations = 50
    local iteration = 0

    repeat
        local scan_result = redis.call("SCAN", cursor, "MATCH", prefix .. "*", "COUNT", 100)
        cursor = scan_result[1]
        local keys = scan_result[2]

        for _, key in ipairs(keys) do
            local freq = 0
            local mem_usage = 0

            -- 获取访问频率（如果启用了 LFU）
            if lfu_enabled then
                local ok, freq_result = pcall(redis.call, "OBJECT", "FREQ", key)
                if ok and freq_result then
                    freq = tonumber(freq_result) or 0
                end
            end

            -- 获取内存使用量
            local ok, mem_result = pcall(redis.call, "MEMORY", "USAGE", key)
            if ok and mem_result then
                mem_usage = tonumber(mem_result) or 0
            end

            -- 添加到候选列表
            if freq > 0 or mem_usage > memory_threshold then
                table.insert(hotspot_candidates, {
                    key = key,
                    freq = freq,
                    mem = mem_usage,
                    score = freq * 1000 + mem_usage  -- 综合得分
                })
            end
        end

        iteration = iteration + 1
    until cursor == "0" or iteration >= max_iterations
end

-- 按得分排序，取 Top N
table.sort(hotspot_candidates, function(a, b) return a.score > b.score end)

-- 输出热点 key 指标
local hotspot_count = 0
for i = 1, math.min(top_n, #hotspot_candidates) do
    local item = hotspot_candidates[i]
    local safe_key = string.gsub(item.key, "[^%w]", "_")

    -- 访问频率指标
    table.insert(result, "hotkey_freq_" .. safe_key)
    table.insert(result, tostring(item.freq))

    -- 内存使用指标
    table.insert(result, "hotkey_memory_bytes_" .. safe_key)
    table.insert(result, tostring(item.mem))

    hotspot_count = hotspot_count + 1
end

-- ============================================
-- 汇总统计
-- ============================================

-- 热点 key 数量
table.insert(result, "hotkey_detected_total")
table.insert(result, tostring(#hotspot_candidates))

-- 大内存 key 数量
local large_key_count = 0
for _, item in ipairs(hotspot_candidates) do
    if item.mem > memory_threshold then
        large_key_count = large_key_count + 1
    end
end
table.insert(result, "large_key_count")
table.insert(result, tostring(large_key_count))

-- LFU 是否启用
table.insert(result, "lfu_policy_enabled")
table.insert(result, lfu_enabled and "1" or "0")

-- ============================================
-- 基于 INFO COMMANDSTATS 的命令热点分析
-- ============================================

-- 获取命令统计中调用次数最多的命令
local cmdstats = redis.call("INFO", "commandstats")
if cmdstats then
    local max_calls = 0
    local hottest_cmd = "none"

    for line in string.gmatch(cmdstats, "[^\r\n]+") do
        local cmd, calls = string.match(line, "cmdstat_(%w+):calls=(%d+)")
        if cmd and calls then
            local call_count = tonumber(calls)
            if call_count > max_calls then
                max_calls = call_count
                hottest_cmd = cmd
            end
        end
    end

    table.insert(result, "hottest_command_calls")
    table.insert(result, tostring(max_calls))
end

return result

