import '../../core/database/database.dart';
import '../models/audit_entry.dart';
import 'audit_chain_status.dart';
import 'audit_entry_hash.dart';
import 'audit_repository.dart';

extension AuditChain on AuditRepository {
  Future<AuditChainStatus> verifyChain() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('audit_log', orderBy: 'timestamp ASC');

    String? expectedPrevious;
    var verified = 0;

    for (final row in rows) {
      final storedHash = row['entry_hash'] as String?;
      final storedPrevious = row['prev_hash'] as String?;

      // Records written before the chain existed carry no hash; they are
      // reported as unverifiable rather than as tampering.
      if (storedHash == null) {
        return AuditChainStatus(
          intact: verified == rows.length,
          verifiedCount: verified,
          totalCount: rows.length,
          unverifiableCount: rows.length - verified,
        );
      }

      final entry = AuditEntry.fromMap(row);
      if (storedPrevious != expectedPrevious || auditEntryHash(entry, storedPrevious) != storedHash) {
        return AuditChainStatus(
          intact: false,
          verifiedCount: verified,
          totalCount: rows.length,
          brokenAt: entry.timestamp,
        );
      }

      expectedPrevious = storedHash;
      verified++;
    }

    return AuditChainStatus(
      intact: true,
      verifiedCount: verified,
      totalCount: rows.length,
    );
  }

  /// Newline-delimited JSON, one record per line.
}
