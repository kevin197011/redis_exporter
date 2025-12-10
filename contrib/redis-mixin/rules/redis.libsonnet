{
  prometheusRules+:: {
    groups+: [
      {
        name: 'redis.rules',
        rules: [
          // ============================================
          // 集群健康度 Recording Rules
          // ============================================
          {
            record: 'redis_cluster:slots_health_ratio',
            expr: 'redis_cluster_slots_ok{%(redisExporterSelector)s} / redis_cluster_slots_assigned{%(redisExporterSelector)s}' % $._config,
          },
          {
            record: 'redis_cluster:slots_fail_total',
            expr: 'redis_cluster_slots_fail{%(redisExporterSelector)s} + redis_cluster_slots_pfail{%(redisExporterSelector)s}' % $._config,
          },
          {
            record: 'redis_cluster:is_healthy',
            expr: |||
              (
                redis_cluster_state{%(redisExporterSelector)s} == 1
                and
                redis_cluster_slots_assigned{%(redisExporterSelector)s} == 16384
                and
                redis_cluster_slots_fail{%(redisExporterSelector)s} == 0
              ) or vector(0)
            ||| % $._config,
          },

          // ============================================
          // 内存使用率 Recording Rules
          // ============================================
          {
            record: 'redis:memory_used_ratio',
            expr: |||
              redis_memory_used_bytes{%(redisExporterSelector)s}
              /
              redis_memory_max_bytes{%(redisExporterSelector)s} > 0
              or
              redis_memory_used_bytes{%(redisExporterSelector)s}
              /
              redis_total_system_memory_bytes{%(redisExporterSelector)s}
            ||| % $._config,
          },
          {
            record: 'redis:memory_used_rss_ratio',
            expr: 'redis_memory_used_rss_bytes{%(redisExporterSelector)s} / redis_total_system_memory_bytes{%(redisExporterSelector)s}' % $._config,
          },

          // ============================================
          // 连接使用率 Recording Rules
          // ============================================
          {
            record: 'redis:connections_used_ratio',
            expr: 'redis_connected_clients{%(redisExporterSelector)s} / redis_config_maxclients{%(redisExporterSelector)s}' % $._config,
          },

          // ============================================
          // 缓存命中率 Recording Rules
          // ============================================
          {
            record: 'redis:keyspace_hit_ratio',
            expr: |||
              rate(redis_keyspace_hits_total{%(redisExporterSelector)s}[5m])
              /
              (
                rate(redis_keyspace_hits_total{%(redisExporterSelector)s}[5m])
                +
                rate(redis_keyspace_misses_total{%(redisExporterSelector)s}[5m])
              )
            ||| % $._config,
          },

          // ============================================
          // 操作速率 Recording Rules
          // ============================================
          {
            record: 'redis:commands_per_second',
            expr: 'rate(redis_commands_processed_total{%(redisExporterSelector)s}[5m])' % $._config,
          },
          {
            record: 'redis:connections_per_second',
            expr: 'rate(redis_connections_received_total{%(redisExporterSelector)s}[5m])' % $._config,
          },
          {
            record: 'redis:evictions_per_second',
            expr: 'rate(redis_evicted_keys_total{%(redisExporterSelector)s}[5m])' % $._config,
          },

          // ============================================
          // 网络吞吐 Recording Rules
          // ============================================
          {
            record: 'redis:net_input_bytes_per_second',
            expr: 'rate(redis_net_input_bytes_total{%(redisExporterSelector)s}[5m])' % $._config,
          },
          {
            record: 'redis:net_output_bytes_per_second',
            expr: 'rate(redis_net_output_bytes_total{%(redisExporterSelector)s}[5m])' % $._config,
          },

          // ============================================
          // 复制延迟 Recording Rules
          // ============================================
          {
            record: 'redis:replication_lag_bytes',
            expr: 'redis_master_repl_offset{%(redisExporterSelector)s} - on(instance) group_right redis_connected_slave_offset_bytes{%(redisExporterSelector)s}' % $._config,
          },

          // ============================================
          // 集群消息速率 Recording Rules
          // ============================================
          {
            record: 'redis_cluster:messages_sent_per_second',
            expr: 'rate(redis_cluster_messages_sent_total{%(redisExporterSelector)s}[5m])' % $._config,
          },
          {
            record: 'redis_cluster:messages_received_per_second',
            expr: 'rate(redis_cluster_messages_received_total{%(redisExporterSelector)s}[5m])' % $._config,
          },
        ],
      },
    ],
  },
}
