/// The credential vault.
///
/// `password`, `private_key` and `passphrase` hold sealed blobs, never
/// plaintext. `public_key`, `fingerprint` and `key_type` are deliberately in
/// the clear so the vault list renders without unlocking anything.
const vaultTables = <String>[
  '''
  CREATE TABLE identities (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'password',
    password TEXT,
    private_key TEXT,
    passphrase TEXT,
    certificate TEXT,
    key_type TEXT,
    public_key TEXT,
    fingerprint TEXT,
    comment TEXT,
    key_bits INTEGER,
    last_used_at TEXT,
    crypto_version INTEGER NOT NULL DEFAULT 2,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
];
