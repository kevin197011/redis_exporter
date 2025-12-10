{
  _config+:: {
    // Selector for redis_exporter metrics
    redisExporterSelector: 'job="redis"',

    // Connection threshold
    redisConnectionsThreshold: '100',

    // Cluster settings
    redisClusterMinNodes: '6',  // Minimum nodes for a healthy cluster (default: 3 masters + 3 replicas)

    // Replication settings
    redisReplicationLagThreshold: '30',  // Seconds

    // Persistence settings
    redisRdbSaveInterval: '3600',  // Seconds (1 hour)

    // Performance thresholds
    redisFragmentationRatioThreshold: '1.5',  // Memory fragmentation ratio
    redisEvictedKeysThreshold: '100',  // Evicted keys per 5 minutes

    // Queue monitoring thresholds
    redisQueueBacklogThreshold: '1000',  // Warning threshold for queue items
    redisQueueBacklogCriticalThreshold: '10000',  // Critical threshold for queue items
    redisQueueGrowthRate: '10',  // Queue growth rate per second

    // Hotkey monitoring thresholds
    redisHotkeyThreshold: '5',  // Number of hotkeys to trigger alert
    redisLargeKeyThreshold: '3',  // Number of large keys to trigger alert
  },
}
