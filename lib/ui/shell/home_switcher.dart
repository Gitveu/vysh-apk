import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/hosts_controller.dart';
import 'ui_state.dart';

/// Переключатель разделов главной: «Хосты · Настройки».
class HomeSwitcher extends ConsumerWidget {
  const HomeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(homeSectionProvider);
    final count = ref.watch(hostsProvider.select((h) => h.length));

    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: 0, vertical: -1),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
      ),
      segments: [
        ButtonSegment(
          value: 0,
          icon: const Icon(Icons.dns_outlined),
          label: Text(count > 0 ? 'Хосты  $count' : 'Хосты'),
        ),
        const ButtonSegment(
          value: 1,
          icon: Icon(Icons.tune),
          label: Text('Настройки'),
        ),
      ],
      selected: {section},
      onSelectionChanged: (s) => ref.read(homeSectionProvider.notifier).select(s.first),
    );
  }
}
