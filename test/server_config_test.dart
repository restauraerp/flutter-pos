import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/config/server_config.dart';

void main() {
  group('ServerConfig.normalize', () {
    test('appends the API prefix to a bare host', () {
      expect(
        ServerConfig.normalize('restauraerp.com'),
        'http://restauraerp.com/api/v1',
      );
    });

    test('keeps an explicit https scheme', () {
      expect(
        ServerConfig.normalize('https://restauraerp.com'),
        'https://restauraerp.com/api/v1',
      );
    });

    test('handles a host:port typed by an operator on a LAN', () {
      expect(
        ServerConfig.normalize('192.168.0.10:8029'),
        'http://192.168.0.10:8029/api/v1',
      );
    });

    test('strips trailing slashes before appending', () {
      expect(
        ServerConfig.normalize('http://localhost:8029///'),
        'http://localhost:8029/api/v1',
      );
    });

    test('leaves an already-complete API URL untouched', () {
      expect(
        ServerConfig.normalize('http://10.0.2.2:8029/api/v1'),
        'http://10.0.2.2:8029/api/v1',
      );
    });

    test('returns empty for empty input', () {
      expect(ServerConfig.normalize('   '), '');
    });
  });
}
