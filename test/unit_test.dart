import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/ui/hosts/hosts_page.dart';
import 'package:vysh/ui/shell/home_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test HostsPage build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HostsPage(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Test HomeTabs build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeTabs(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
