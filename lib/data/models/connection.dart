enum ConnectionType {
  ssh,
  sftp,
  ftp,
  ftps,
  https,
  snmp,
  winrm,
}

extension ConnectionTypeExtension on ConnectionType {
  String get label {
    switch (this) {
      case ConnectionType.ssh:
        return 'SSH';
      case ConnectionType.sftp:
        return 'SFTP';
      case ConnectionType.ftp:
        return 'FTP';
      case ConnectionType.ftps:
        return 'FTPS';
      case ConnectionType.https:
        return 'HTTPS';
      case ConnectionType.snmp:
        return 'SNMP';
      case ConnectionType.winrm:
        return 'WinRM';
    }
  }

  int get defaultPort {
    switch (this) {
      case ConnectionType.ssh:
      case ConnectionType.sftp:
        return 22;
      case ConnectionType.ftp:
        return 21;
      case ConnectionType.ftps:
        return 990;
      case ConnectionType.https:
        return 443;
      case ConnectionType.snmp:
        return 161;
      case ConnectionType.winrm:
        return 5986;
    }
  }
}
