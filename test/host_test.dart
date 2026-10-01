import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/domain/models/host.dart';

void main() {
  test('Host переживает JSON туда-обратно', () {
    const h = Host(
      id: 'abc',
      label: 'web',
      address: '10.0.0.5',
      port: 2222,
      username: 'admin',
      auth: AuthMethod.key,
      keyPath: '~/.ssh/id_ed25519',
      group: 'prod',
    );
    final back = Host.fromJson(h.toJson());
    expect(back.id, h.id);
    expect(back.address, h.address);
    expect(back.port, 2222);
    expect(back.auth, AuthMethod.key);
    expect(back.keyPath, h.keyPath);
    expect(back.displayAddress, 'admin@10.0.0.5:2222');
  });

  test('Быстрое подключение разбирается', () {
    final h = Host.tryParseQuick('root@192.168.1.10:2200')!;
    expect(h.username, 'root');
    expect(h.address, '192.168.1.10');
    expect(h.port, 2200);

    expect(Host.tryParseQuick('example.com')!.username, 'root');
    expect(Host.tryParseQuick('просто текст'), isNull);
    expect(Host.tryParseQuick('web'), isNull);
  });
}
