import 'package:flutter_test/flutter_test.dart';
import 'package:admin_toolbox/data/models/host.dart';
import 'package:admin_toolbox/data/models/group.dart';
import 'package:admin_toolbox/data/models/identity.dart';
import 'package:admin_toolbox/data/models/command.dart';
import 'package:admin_toolbox/data/models/connection.dart';
import 'package:admin_toolbox/core/utils/extensions.dart';
import 'package:admin_toolbox/core/theme/app_theme.dart';

void main() {
  group('Host Model', () {
    test('should serialize to and from map', () {
      final now = DateTime.now();
      final host = Host(
        id: 'test-1',
        name: 'Web Server',
        hostname: '192.168.1.100',
        port: 22,
        tags: ['production', 'web'],
        favorite: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = host.toMap();
      final restored = Host.fromMap(map);

      expect(restored.id, equals(host.id));
      expect(restored.name, equals(host.name));
      expect(restored.hostname, equals(host.hostname));
      expect(restored.port, equals(22));
      expect(restored.tags, containsAll(['production', 'web']));
      expect(restored.favorite, isTrue);
    });

    test('should handle copyWith', () {
      final now = DateTime.now();
      final host = Host(
        id: 'test-1',
        name: 'Web Server',
        hostname: '192.168.1.100',
        createdAt: now,
        updatedAt: now,
      );

      final updated = host.copyWith(name: 'Updated Server', port: 2222);
      expect(updated.name, equals('Updated Server'));
      expect(updated.port, equals(2222));
      expect(updated.id, equals('test-1'));
    });
  });

  group('Group Model', () {
    test('should serialize to and from map', () {
      final now = DateTime.now();
      final group = Group(
        id: 'g1',
        name: 'Production',
        description: 'Production servers',
        createdAt: now,
        updatedAt: now,
      );

      final map = group.toMap();
      final restored = Group.fromMap(map);

      expect(restored.id, equals('g1'));
      expect(restored.name, equals('Production'));
      expect(restored.description, equals('Production servers'));
    });
  });

  group('Identity Model', () {
    test('should serialize to map', () {
      final now = DateTime.now();
      final identity = Identity(
        id: 'i1',
        name: 'Admin Key',
        type: 'ssh_key',
        username: 'admin',
        privateKey: 'PRIVATE_KEY_CONTENT',
        createdAt: now,
        updatedAt: now,
      );

      final map = identity.toMap();
      expect(map['id'], equals('i1'));
      expect(map['type'], equals('ssh_key'));
      expect(map['username'], equals('admin'));
    });
  });

  group('Command Model', () {
    test('should interpolate variables', () {
      final command = Command(
        id: 'c1',
        name: 'Restart Service',
        command: 'systemctl restart {{service}}',
        variables: ['service'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = command.interpolate({'service': 'nginx'});
      expect(result, equals('systemctl restart nginx'));
    });
  });

  group('ConnectionType', () {
    test('should return correct default ports', () {
      expect(ConnectionType.ssh.defaultPort, equals(22));
      expect(ConnectionType.ftp.defaultPort, equals(21));
      expect(ConnectionType.https.defaultPort, equals(443));
    });

    test('should return correct labels', () {
      expect(ConnectionType.ssh.label, equals('SSH'));
      expect(ConnectionType.sftp.label, equals('SFTP'));
    });
  });

  group('Extensions', () {
    test('formatBytes should format correctly', () {
      expect(formatBytes(0), equals('0 B'));
      expect(formatBytes(1024), equals('1.0 KB'));
      expect(formatBytes(1048576), equals('1.0 MB'));
      expect(formatBytes(1073741824), equals('1.0 GB'));
    });

    test('formatPercent should format correctly', () {
      expect(formatPercent(75.5), equals('75.5%'));
      expect(formatPercent(0), equals('0.0%'));
    });

    test('String capitalize', () {
      expect('hello'.capitalize, equals('Hello'));
      expect(''.capitalize, equals(''));
    });
  });

  group('AppTheme', () {
    test('severityColor returns correct colors', () {
      expect(AppTheme.severityColor('critical'), equals(AppTheme.dangerRed));
      expect(AppTheme.severityColor('warning'), equals(AppTheme.warningOrange));
      expect(AppTheme.severityColor('info'), equals(AppTheme.infoCyan));
      expect(AppTheme.severityColor('unknown'), equals(AppTheme.textMuted));
    });

    test('statusColor returns correct colors', () {
      expect(AppTheme.statusColor('online'), equals(AppTheme.successGreen));
      expect(AppTheme.statusColor('offline'), equals(AppTheme.dangerRed));
      expect(AppTheme.statusColor('unknown'), equals(AppTheme.textMuted));
    });
  });
}
