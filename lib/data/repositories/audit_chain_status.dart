class AuditChainStatus {
  const AuditChainStatus({
    required this.intact,
    required this.verifiedCount,
    required this.totalCount,
    this.brokenAt,
    this.unverifiableCount = 0,
  });

  final bool intact;
  final int verifiedCount;
  final int totalCount;

  /// Timestamp of the first record that failed verification.
  final DateTime? brokenAt;

  /// Pre-migration records that carry no hash.
  final int unverifiableCount;
}
