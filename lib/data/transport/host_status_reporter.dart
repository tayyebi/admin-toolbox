import 'dart:async';

import '../repositories/host_repository.dart';
import 'host_key_rejected_exception.dart';
import 'missing_identity_exception.dart';

/// Records what a connection attempt revealed about a host.
///
/// The distinctions matter to the user: a host with no credential is a
/// configuration problem, not a network one, and a refused host key is a
/// security decision that says nothing about reachability either way.
class HostStatusReporter {
  HostStatusReporter({HostRepository? hosts}) : _hosts = hosts ?? HostRepository();

  final HostRepository _hosts;

  Future<T> record<T>(String hostId, Future<T> attempt) async {
    try {
      final result = await attempt;
      // Otherwise the status pill only moves once background monitoring
      // (opt-in, off by default) happens to sweep this host, so a host you can
      // visibly open a terminal on still shows "Unknown" indefinitely.
      unawaited(_hosts.updateStatus(hostId, 'online'));
      return result;
    } on MissingIdentityException {
      unawaited(_hosts.updateStatus(hostId, 'unknown'));
      rethrow;
    } on HostKeyRejectedException {
      rethrow;
    } catch (_) {
      unawaited(_hosts.updateStatus(hostId, 'offline'));
      rethrow;
    }
  }
}
