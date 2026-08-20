enum IdentityType {
  password,
  sshKey;

  static IdentityType parse(String? raw) {
    switch (raw) {
      case 'ssh_key':
      case 'sshKey':
        return IdentityType.sshKey;
      default:
        return IdentityType.password;
    }
  }

  String get storageValue => this == IdentityType.sshKey ? 'ssh_key' : 'password';

  String get label => this == IdentityType.sshKey ? 'SSH Key' : 'Password';
}

/// A credential in the vault.
///
/// [password], [privateKey] and [passphrase] hold plaintext only while an
/// instance is in flight between the repository and the UI — at rest they are
/// AES-GCM sealed. [publicKey] and [fingerprint] are deliberately *not*
/// secret, so the vault list can render without decrypting every record.
