{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'redis',
        rules: [
          // ============================================
          // 基础可用性告警
          // ============================================
          {
            alert: 'RedisDown',
            expr: 'redis_up{%(redisExporterSelector)s} == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis down (instance {{ $labels.instance }})',
              description: 'Redis instance is down\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisOutOfMemory',
            expr: 'redis_memory_used_bytes{%(redisExporterSelector)s} / redis_total_system_memory_bytes{%(redisExporterSelector)s} * 100 > 90' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis out of memory (instance {{ $labels.instance }})',
              description: 'Redis is running out of memory (> 90%)\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisTooManyConnections',
            expr: 'redis_connected_clients{%(redisExporterSelector)s} > %(redisConnectionsThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis too many connections (instance {{ $labels.instance }})',
              description: 'Redis instance has too many connections\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 集群 Slots 健康度告警
          // ============================================
          {
            alert: 'RedisClusterSlotFail',
            expr: 'redis_cluster_slots_fail{%(redisExporterSelector)s} > 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster slots in FAIL state (instance {{ $labels.instance }})',
              description: 'Redis cluster has {{ $value }} slots in FAIL state. This indicates nodes are confirmed down.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisClusterSlotPfail',
            expr: 'redis_cluster_slots_pfail{%(redisExporterSelector)s} > 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster slots in PFAIL state (instance {{ $labels.instance }})',
              description: 'Redis cluster has {{ $value }} slots in PFAIL (possible failure) state. Nodes may be unreachable.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisClusterStateNotOk',
            expr: 'redis_cluster_state{%(redisExporterSelector)s} == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis cluster state is FAIL (instance {{ $labels.instance }})',
              description: 'Redis cluster state is not OK. The cluster cannot accept writes and may have slots unavailable.\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 集群 Slots 完整性告警
          // ============================================
          {
            alert: 'RedisClusterSlotsIncomplete',
            expr: 'redis_cluster_slots_assigned{%(redisExporterSelector)s} < 16384' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis cluster slots not fully assigned (instance {{ $labels.instance }})',
              description: 'Redis cluster only has {{ $value }}/16384 slots assigned. Some slots are not covered by any node.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisClusterSlotsNotOk',
            expr: 'redis_cluster_slots_ok{%(redisExporterSelector)s} < redis_cluster_slots_assigned{%(redisExporterSelector)s}' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster has unhealthy slots (instance {{ $labels.instance }})',
              description: 'Redis cluster has slots that are not in OK state. OK slots: {{ $value }}\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 集群节点健康度告警
          // ============================================
          {
            alert: 'RedisClusterNodeDown',
            expr: 'delta(redis_cluster_known_nodes{%(redisExporterSelector)s}[5m]) < -1' % $._config,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster lost node(s) (instance {{ $labels.instance }})',
              description: 'Redis cluster known nodes decreased by {{ $value | humanize }} in the last 5 minutes.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisClusterTooFewNodes',
            expr: 'redis_cluster_known_nodes{%(redisExporterSelector)s} < %(redisClusterMinNodes)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis cluster has too few nodes (instance {{ $labels.instance }})',
              description: 'Redis cluster has only {{ $value }} nodes, expected at least %(redisClusterMinNodes)s.\n  LABELS: {{ $labels }}' % $._config,
            },
          },
          {
            alert: 'RedisClusterSizeChanged',
            expr: 'changes(redis_cluster_size{%(redisExporterSelector)s}[10m]) > 0' % $._config,
            'for': '1m',
            labels: {
              severity: 'info',
            },
            annotations: {
              summary: 'Redis cluster size changed (instance {{ $labels.instance }})',
              description: 'Redis cluster size (number of master nodes serving at least one slot) has changed. Current size: {{ $value }}\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 集群通信健康度告警
          // ============================================
          {
            alert: 'RedisClusterMessageStalled',
            expr: 'rate(redis_cluster_messages_sent_total{%(redisExporterSelector)s}[5m]) == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster message sending stalled (instance {{ $labels.instance }})',
              description: 'Redis cluster is not sending any gossip messages. This may indicate network isolation.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisClusterMessageReceiveStalled',
            expr: 'rate(redis_cluster_messages_received_total{%(redisExporterSelector)s}[5m]) == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis cluster message receiving stalled (instance {{ $labels.instance }})',
              description: 'Redis cluster is not receiving any gossip messages. This may indicate network isolation.\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 复制健康度告警
          // ============================================
          {
            alert: 'RedisReplicationBroken',
            expr: 'redis_master_link_up{%(redisExporterSelector)s} == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis replication broken (instance {{ $labels.instance }})',
              description: 'Redis slave has lost connection to master ({{ $labels.master_host }}:{{ $labels.master_port }}).\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisReplicationLag',
            expr: 'redis_connected_slave_lag_seconds{%(redisExporterSelector)s} > %(redisReplicationLagThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis replication lag too high (instance {{ $labels.instance }})',
              description: 'Redis slave replication lag is {{ $value | humanizeDuration }} (threshold: %(redisReplicationLagThreshold)ss).\n  LABELS: {{ $labels }}' % $._config,
            },
          },

          // ============================================
          // 持久化健康度告警
          // ============================================
          {
            alert: 'RedisRdbLastSaveTooOld',
            expr: 'time() - redis_rdb_last_save_timestamp_seconds{%(redisExporterSelector)s} > %(redisRdbSaveInterval)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis RDB last save too old (instance {{ $labels.instance }})',
              description: 'Redis last RDB save was {{ $value | humanizeDuration }} ago.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisRdbBgsaveFailed',
            expr: 'redis_rdb_last_bgsave_status{%(redisExporterSelector)s} == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis RDB BGSAVE failed (instance {{ $labels.instance }})',
              description: 'Redis last RDB background save failed.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisAofRewriteFailed',
            expr: 'redis_aof_last_bgrewrite_status{%(redisExporterSelector)s} == 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis AOF rewrite failed (instance {{ $labels.instance }})',
              description: 'Redis last AOF background rewrite failed.\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 性能告警
          // ============================================
          {
            alert: 'RedisMemoryFragmentationHigh',
            expr: 'redis_mem_fragmentation_ratio{%(redisExporterSelector)s} > %(redisFragmentationRatioThreshold)s' % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis memory fragmentation high (instance {{ $labels.instance }})',
              description: 'Redis memory fragmentation ratio is {{ $value | printf "%%.2f" }} (threshold: %(redisFragmentationRatioThreshold)s). Consider restarting Redis.\n  LABELS: {{ $labels }}' % $._config,
            },
          },
          {
            alert: 'RedisEvictingKeys',
            expr: 'increase(redis_evicted_keys_total{%(redisExporterSelector)s}[5m]) > %(redisEvictedKeysThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis evicting keys (instance {{ $labels.instance }})',
              description: 'Redis is evicting {{ $value | humanize }} keys in the last 5 minutes due to maxmemory limit.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisRejectedConnections',
            expr: 'increase(redis_rejected_connections_total{%(redisExporterSelector)s}[5m]) > 0' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis rejecting connections (instance {{ $labels.instance }})',
              description: 'Redis rejected {{ $value | humanize }} connections in the last 5 minutes.\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // 队列长度告警 (需要配置 --check-single-keys 或 --script)
          // ============================================
          {
            alert: 'RedisQueueBacklog',
            expr: 'redis_key_size{%(redisExporterSelector)s, key=~"queue:.*|celery.*|bull:.*"} > %(redisQueueBacklogThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis queue backlog high (instance {{ $labels.instance }})',
              description: 'Queue {{ $labels.key }} has {{ $value | humanize }} items pending.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisQueueBacklogCritical',
            expr: 'redis_key_size{%(redisExporterSelector)s, key=~"queue:.*|celery.*|bull:.*"} > %(redisQueueBacklogCriticalThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Redis queue backlog critical (instance {{ $labels.instance }})',
              description: 'Queue {{ $labels.key }} has {{ $value | humanize }} items pending, critical threshold exceeded.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisQueueGrowing',
            expr: 'deriv(redis_key_size{%(redisExporterSelector)s, key=~"queue:.*|celery.*|bull:.*"}[10m]) > %(redisQueueGrowthRate)s' % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis queue growing rapidly (instance {{ $labels.instance }})',
              description: 'Queue {{ $labels.key }} is growing at {{ $value | humanize }}/sec.\n  LABELS: {{ $labels }}',
            },
          },

          // ============================================
          // Key 热点告警 (需要配置 --script=collect_key_hotspot.lua)
          // ============================================
          {
            alert: 'RedisHotkeyDetected',
            expr: 'redis_script_values{%(redisExporterSelector)s, key="hotkey_detected_total"} > %(redisHotkeyThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis hotkey detected (instance {{ $labels.instance }})',
              description: 'Detected {{ $value | humanize }} hot keys in Redis instance.\n  LABELS: {{ $labels }}',
            },
          },
          {
            alert: 'RedisLargeKeyDetected',
            expr: 'redis_script_values{%(redisExporterSelector)s, key="large_key_count"} > %(redisLargeKeyThreshold)s' % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Redis large keys detected (instance {{ $labels.instance }})',
              description: 'Detected {{ $value | humanize }} keys exceeding memory threshold.\n  LABELS: {{ $labels }}',
            },
          },
        ],
      },
    ],
  },
}
