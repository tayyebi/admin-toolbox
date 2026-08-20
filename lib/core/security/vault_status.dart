enum VaultStatus {
  /// Startup state, before secure storage has been consulted.
  unknown,

  /// No master password has ever been set on this device.
  needsSetup,
  locked,
  unlocked,
}
