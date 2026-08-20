/// Numeric metric ids an alert rule can be written against.
///
/// Listed explicitly rather than derived from the registry, because collectors
/// emit several metrics each and only some are numbers — thresholding
/// `sys_hostname` is not meaningful.
const List<String> knownMetricIds = [
  'cpu_usage',
  'cpu_user',
  'cpu_system',
  'cpu_iowait',
  'cpu_temp',
  'memory_usage_pct',
  'memory_used',
  'memory_free',
  'swap_usage_pct',
  'disk_usage_pct',
  'disk_free',
  'disk_inodes',
  'proc_running',
  'proc_zombies',
  'svc_failed',
  'svc_running',
  'docker_containers',
  'sec_failed_logins',
  'sec_open_ports',
  'sys_uptime',
  'sys_logged_users',
];
