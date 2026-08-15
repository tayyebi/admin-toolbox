import 'package:admin_toolbox/core/utils/extensions.dart';
import 'package:admin_toolbox/core/utils/json_codec.dart';
import 'package:admin_toolbox/data/models/automation.dart';
import 'package:admin_toolbox/data/models/command.dart';
import 'package:admin_toolbox/data/models/connection.dart';
import 'package:admin_toolbox/data/models/group.dart';
import 'package:admin_toolbox/data/models/host.dart';
import 'package:admin_toolbox/data/models/identity.dart';
import 'package:admin_toolbox/data/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Host', () {
    test('round-trips through a map', () {
      final now = DateTime.now();
      final host = Host(
        id: 'test-1',
        name: 'Web Server',
        hostname: '192.168.1.100',
        port: 22,
        identityId: 'identity-1',
        tags: ['production', 'web'],
        favorite: true,
        createdAt: now,
        updatedAt: now,
      );

      final restored = Host.fromMap(host.toMap());

      expect(restored.id, host.id);
      expect(restored.name, host.name);
      expect(restored.hostname, host.hostname);
      expect(restored.port, 22);
      expect(restored.identityId, 'identity-1');
      expect(restored.tags, containsAll(['production', 'web']));
      expect(restored.favorite, isTrue);
    });

    test('preserves tags containing a comma', () {
      // The old encoding joined tags with commas, so this tag split in two.
      final now = DateTime.now();
      final host = Host(
        id: 'h1',
        name: 'n',
        hostname: 'h',
        tags: const ['team: infra, platform', 'prod'],
        createdAt: now,
        updatedAt: now,
      );

      final restored = Host.fromMap(host.toMap());
      expect(restored.tags, hasLength(2));
      expect(restored.tags.first, 'team: infra, platform');
    });

    test('preserves metadata values containing = and ,', () {
      final now = DateTime.now();
      final host = Host(
        id: 'h1',
        name: 'n',
        hostname: 'h',
        metadata: const {'motd': 'a=b,c=d', 'region': 'eu-west-1'},
        createdAt: now,
        updatedAt: now,
      );

      final restored = Host.fromMap(host.toMap());
      expect(restored.metadata['motd'], 'a=b,c=d');
      expect(restored.metadata['region'], 'eu-west-1');
    });

    test('reads legacy comma-joined tags', () {
      final now = DateTime.now().toIso8601String();
      final restored = Host.fromMap({
        'id': 'h1',
        'name': 'n',
        'hostname': 'h',
        'port': 22,
        'tags': 'production,web',
        'created_at': now,
        'updated_at': now,
      });

      expect(restored.tags, ['production', 'web']);
    });

    test('copyWith replaces only what it is given', () {
      final now = DateTime.now();
      final host = Host(
        id: 'test-1',
        name: 'Web Server',
        hostname: '192.168.1.100',
        createdAt: now,
        updatedAt: now,
      );

      final updated = host.copyWith(name: 'Updated Server', port: 2222);
      expect(updated.name, 'Updated Server');
      expect(updated.port, 2222);
      expect(updated.id, 'test-1');
      expect(updated.hostname, '192.168.1.100');
    });
  });

  group('Group', () {
    test('round-trips through a map', () {
      final now = DateTime.now();
      final group = Group(
        id: 'g1',
        name: 'Production',
        description: 'Production servers',
        createdAt: now,
        updatedAt: now,
      );

      final restored = Group.fromMap(group.toMap());
      expect(restored.id, 'g1');
      expect(restored.name, 'Production');
      expect(restored.description, 'Production servers');
    });
  });

  group('Identity', () {
    test('round-trips through a map', () {
      final now = DateTime.now();
      final identity = Identity(
        id: 'i1',
        name: 'Admin Key',
        type: IdentityType.sshKey,
        privateKey: 'PRIVATE_KEY_CONTENT',
        fingerprint: 'SHA256:abcdef',
        createdAt: now,
        updatedAt: now,
      );

      final restored = Identity.fromMap(identity.toMap());
      expect(restored.id, 'i1');
      expect(restored.type, IdentityType.sshKey);
      expect(restored.fingerprint, 'SHA256:abcdef');
    });

    test('rows without crypto_version are treated as v1', () {
      final now = DateTime.now().toIso8601String();
      final restored = Identity.fromMap({
        'id': 'i1',
        'name': 'n',
        'type': 'ssh_key',
        'created_at': now,
        'updated_at': now,
      });

      expect(restored.cryptoVersion, 1);
      expect(restored.needsMigration, isTrue);
    });

    test('redacted() drops every secret', () {
      final now = DateTime.now();
      final identity = Identity(
        id: 'i1',
        name: 'n',
        type: IdentityType.sshKey,
        password: 'hunter2',
        privateKey: 'KEY',
        passphrase: 'pass',
        publicKey: 'ssh-rsa AAAA',
        createdAt: now,
        updatedAt: now,
      );

      final redacted = identity.redacted();
      expect(redacted.password, isNull);
      expect(redacted.privateKey, isNull);
      expect(redacted.passphrase, isNull);
      // Public material is not secret and must survive.
      expect(redacted.publicKey, 'ssh-rsa AAAA');
    });

    test('toString never leaks a secret', () {
      final now = DateTime.now();
      final identity = Identity(
        id: 'i1',
        name: 'n',
        type: IdentityType.password,
        password: 'hunter2',
        privateKey: 'SUPER_SECRET_KEY',
        createdAt: now,
        updatedAt: now,
      );

      final text = identity.toString();
      expect(text, isNot(contains('hunter2')));
      expect(text, isNot(contains('SUPER_SECRET_KEY')));
      expect(text, contains('redacted'));
    });
  });

  group('Command', () {
    test('interpolates variables', () {
      final command = Command(
        id: 'c1',
        name: 'Restart Service',
        command: 'systemctl restart {{service}}',
        variables: const ['service'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(command.interpolate({'service': 'nginx'}), 'systemctl restart nginx');
    });

    test('finds placeholders in the command text', () {
      final found = Command.placeholdersIn('cp {{src}} {{dest}} && chown {{owner}} {{dest}}');
      expect(found, containsAll(['src', 'dest', 'owner']));
      // Repeats collapse.
      expect(found, hasLength(3));
    });
  });

  group('Automation', () {
    test('round-trips steps containing pipes and newlines', () {
      // The old encoding joined steps with '|' and '\n', so this command was
      // silently split into fragments.
      final now = DateTime.now();
      final automation = Automation(
        id: 'a1',
        name: 'Check',
        steps: const [
          AutomationStep(command: "ps aux | grep nginx | awk '{print \$2}'"),
          AutomationStep(command: 'echo one\necho two', continueOnFailure: true),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final restored = Automation.fromMap(automation.toMap());

      expect(restored.steps, hasLength(2));
      expect(restored.steps.first.command, "ps aux | grep nginx | awk '{print \$2}'");
      expect(restored.steps[1].command, 'echo one\necho two');
      expect(restored.steps[1].continueOnFailure, isTrue);
    });

    test('reads legacy pipe-delimited steps', () {
      final now = DateTime.now().toIso8601String();
      final restored = Automation.fromMap({
        'id': 'a1',
        'name': 'Legacy',
        'steps': 'command|systemctl restart nginx\ncommand|systemctl status nginx',
        'created_at': now,
        'updated_at': now,
      });

      expect(restored.steps, hasLength(2));
      expect(restored.steps.first.command, 'systemctl restart nginx');
    });

    test('step interpolation matches Command', () {
      const step = AutomationStep(command: 'systemctl restart {{service}}');
      expect(step.interpolate({'service': 'redis'}), 'systemctl restart redis');
    });
  });

  group('Incident', () {
    test('reads the timeline back', () {
      // fromMap used to hardcode `timeline: []`, so entries were written and
      // never recoverable.
      final now = DateTime.now();
      final incident = Incident(
        id: 'inc1',
        title: 'Database down',
        affectedHosts: const ['h1', 'h2'],
        timeline: [
          IncidentTimelineEntry(
            id: 'e1',
            action: 'opened',
            description: 'Primary stopped responding',
            timestamp: now,
          ),
          IncidentTimelineEntry(
            id: 'e2',
            action: 'update',
            description: 'Failed over to replica',
            timestamp: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final restored = Incident.fromMap(incident.toMap());

      expect(restored.timeline, hasLength(2));
      expect(restored.timeline.first.action, 'opened');
      expect(restored.timeline[1].description, 'Failed over to replica');
      expect(restored.affectedHosts, ['h1', 'h2']);
    });
  });

  group('ConnectionType', () {
    test('reports default ports', () {
      expect(ConnectionType.ssh.defaultPort, 22);
      expect(ConnectionType.ftp.defaultPort, 21);
      expect(ConnectionType.https.defaultPort, 443);
    });

    test('reports labels', () {
      expect(ConnectionType.ssh.label, 'SSH');
      expect(ConnectionType.sftp.label, 'SFTP');
    });
  });

  group('json_codec', () {
    test('decodes both JSON and legacy shapes', () {
      expect(decodeStringList('["a","b"]'), ['a', 'b']);
      expect(decodeStringList('a,b'), ['a', 'b']);
      expect(decodeStringList(null), isEmpty);
      expect(decodeStringList(''), isEmpty);

      expect(decodeStringMap('{"k":"v"}'), {'k': 'v'});
      expect(decodeStringMap('k=v'), {'k': 'v'});
      expect(decodeStringMap(null), isEmpty);
    });

    test('parseDateOrNull tolerates junk', () {
      expect(parseDateOrNull(null), isNull);
      expect(parseDateOrNull(''), isNull);
      expect(parseDateOrNull('not a date'), isNull);
      expect(parseDateOrNull('2026-01-01T00:00:00.000'), isNotNull);
    });
  });

  group('formatBytes', () {
    test('formats exact powers of 1024', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1048576), '1.0 MB');
      expect(formatBytes(1073741824), '1.0 GB');
    });

    test('keeps the fraction for non-exact values', () {
      // Previously returned '1.0 KB': integer division truncated, and the
      // divisor was always 1.
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1610612736), '1.5 GB');
      expect(formatBytes(2621440), '2.5 MB');
    });

    test('reports plain bytes without a decimal point', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1), '1 B');
    });

    test('handles negatives and huge values', () {
      expect(formatBytes(-5), '0 B');
      expect(formatBytes(1125899906842624), '1.0 PB');
    });
  });

  group('formatting helpers', () {
    test('formatPercent', () {
      expect(formatPercent(75.5), '75.5%');
      expect(formatPercent(0), '0.0%');
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(seconds: 30)), '<1m');
      expect(formatDuration(const Duration(minutes: 5)), '5m');
      expect(formatDuration(const Duration(days: 2, hours: 3)), '2d 3h');
    });

    test('String.capitalize', () {
      expect('hello'.capitalize, 'Hello');
      expect(''.capitalize, '');
    });

    test('DateTime.timeAgo', () {
      final now = DateTime.now();
      expect(now.subtract(const Duration(seconds: 5)).timeAgo, endsWith('s ago'));
      expect(now.subtract(const Duration(minutes: 5)).timeAgo, '5m ago');
      expect(now.subtract(const Duration(hours: 3)).timeAgo, '3h ago');
      expect(now.subtract(const Duration(days: 2)).timeAgo, '2d ago');
      // A clock skew must not render as a negative duration.
      expect(now.add(const Duration(minutes: 5)).timeAgo, 'just now');
    });
  });
}
