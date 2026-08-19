/// Indexes, kept separate from the table definitions because migrations
/// re-run them: `IF NOT EXISTS` makes applying the whole set idempotent.
const indexStatements = <String>[
  'CREATE INDEX IF NOT EXISTS idx_metrics_host ON metrics(host_id, collector_id, timestamp)',
  'CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp)',
  'CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status, host_id)',
  'CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp)',
  'CREATE INDEX IF NOT EXISTS idx_hosts_group ON hosts(group_id)',
  'CREATE INDEX IF NOT EXISTS idx_hosts_identity ON hosts(identity_id)',
  'CREATE INDEX IF NOT EXISTS idx_known_hosts_lookup ON known_hosts(hostname, port)',
  'CREATE INDEX IF NOT EXISTS idx_runs_automation ON automation_runs(automation_id, started_at)',
];
