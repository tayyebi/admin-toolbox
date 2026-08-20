import '../../data/transport/ssh_client.dart';

/// What the user is actually being asked, in each of the two cases.
String hostKeyExplanation(HostKeyPrompt prompt) {
  final endpoint = '${prompt.hostname}:${prompt.port}';
  if (prompt.isMismatch) {
    return 'The key presented by $endpoint does not match the one you trusted '
        'before. This happens when a server is rebuilt — but it is also exactly '
        'what a machine-in-the-middle attack looks like.';
  }
  return 'You have not connected to $endpoint before. Check the fingerprint '
      'matches what the server reports from '
      '`ssh-keygen -lf /etc/ssh/ssh_host_*_key.pub`.';
}
