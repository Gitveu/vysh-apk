import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vysh/infra/storage/app_paths.dart';
import 'package:vysh/ui/hosts/hosts_page.dart';
import 'package:vysh/ui/shell/home_switcher.dart';

void main() {
  testWidgets('Test HostsPage build', (tester) async {
    await AppPaths.init();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HostsPage(),
          ),
        ),
      ),
    );
    final error = tester.takeException();
    if (error != null) {
      print('HOSTSPAGE ERROR: $error');
    } else {
      print('HOSTSPAGE SUCCESS');
    }
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
    final error = tester.takeException();
    if (error != null) {
      print('HOMETABS ERROR: $error');
    } else {
      print('HOMETABS SUCCESS');
    }
  });
}
