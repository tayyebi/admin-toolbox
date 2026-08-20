class TransportConnectionConfig {
  const TransportConnectionConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.connectTimeout = const Duration(seconds: 15),
    this.commandTimeout = const Duration(seconds: 30),
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final Duration connectTimeout;
  final Duration commandTimeout;

  /// Never includes credentials — this type ends up in log lines.
  @override
  String toString() => 'TransportConnectionConfig($username@$host:$port)';
}
