/// What an attempt to open the vault produced.
///
/// [rejected] means the credential was wrong, or the user dismissed the
/// prompt — expected, and the caller decides whether it counts against the
/// attempt limit. [unavailable] means the wrap being asked for is not set up.
/// [failed] means something broke.
enum UnlockResult { succeeded, rejected, unavailable, failed }
