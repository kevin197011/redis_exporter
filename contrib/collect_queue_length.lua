-- Queue Length Collector Script
-- 队列长度采集脚本
-- Usage: --script=/path/to/collect_queue_length.lua
--
-- 此脚本用于采集多个队列的长度，适用于需要监控大量队列的场景
-- 比 --check-single-keys 更灵活，可以动态获取队列列表

local result = {}

-- 配置：定义需要监控的队列前缀
local queue_prefixes = {
    "queue:",          -- 通用队列
    "celery:",         -- Celery 任务队列
    "bull:",           -- Bull.js 队列
    "sidekiq:queue:",  -- Sidekiq 队列
    "resque:queue:",   -- Resque 队列
    "delayed_job:",    -- Delayed Job 队列
}

-- 配置：定义具体需要监控的队列名称（可选）
local specific_queues = {
    -- "orders",
    -- "notifications",
    -- "emails",
}

-- 辅助函数：获取 List 长度
local function get_list_length(key)
    local len = redis.call("LLEN", key)
    return len or 0
end

-- 辅助函数：获取 Stream 长度
local function get_stream_length(key)
    local len = redis.call("XLEN", key)
    return len or 0
end

-- 辅助函数：获取 Sorted Set 长度 (延迟队列常用)
local function get_zset_length(key)
    local len = redis.call("ZCARD", key)
    return len or 0
end

-- 按前缀扫描队列
for _, prefix in ipairs(queue_prefixes) do
    local cursor = "0"
    local max_iterations = 100  -- 防止无限循环
    local iteration = 0

    repeat
        local scan_result = redis.call("SCAN", cursor, "MATCH", prefix .. "*", "COUNT", 100)
        cursor = scan_result[1]
        local keys = scan_result[2]

        for _, key in ipairs(keys) do
            local key_type = redis.call("TYPE", key)["ok"] or redis.call("TYPE", key)
            local length = 0

            if key_type == "list" then
                length = get_list_length(key)
            elseif key_type == "stream" then
                length = get_stream_length(key)
            elseif key_type == "zset" then
                length = get_zset_length(key)
            end

            if length > 0 then
                -- 格式: queue_length_<sanitized_key_name>
                local metric_name = "queue_length_" .. string.gsub(key, "[^%w]", "_")
                table.insert(result, metric_name)
                table.insert(result, tostring(length))
            end
        end

        iteration = iteration + 1
    until cursor == "0" or iteration >= max_iterations
end

-- 采集特定队列
for _, queue_name in ipairs(specific_queues) do
    local key_type = redis.call("TYPE", queue_name)["ok"] or redis.call("TYPE", queue_name)
    local length = 0

    if key_type == "list" then
        length = get_list_length(queue_name)
    elseif key_type == "stream" then
        length = get_stream_length(queue_name)
    elseif key_type == "zset" then
        length = get_zset_length(queue_name)
    end

    local metric_name = "queue_length_" .. string.gsub(queue_name, "[^%w]", "_")
    table.insert(result, metric_name)
    table.insert(result, tostring(length))
end

-- 汇总统计
local total_queues = #result / 2
table.insert(result, "queues_monitored_total")
table.insert(result, tostring(total_queues))

return result

