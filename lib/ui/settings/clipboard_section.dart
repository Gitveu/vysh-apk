import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/services/settings_controller.dart';
import 'setting_row.dart';

class ClipboardSection extends ConsumerWidget {
  const ClipboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final strings = AppStrings.of(context, s.language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.copyOnSelectTitle),
          subtitle: Text(strings.copyOnSelectDesc),
          value: s.copyOnSelect,
          onChanged: ctrl.setCopyOnSelect,
        ),
        SettingRow(
          label: strings.rightClickTitle,
          child: DropdownButton<RightClickAction>(
            value: s.rightClick,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem(
                value: RightClickAction.menu,
                child: Text(strings.rightClickMenu),
              ),
              DropdownMenuItem(
                value: RightClickAction.paste,
                child: Text(strings.rightClickPaste),
              ),
              DropdownMenuItem(
                value: RightClickAction.smart,
                child: Text(strings.rightClickSmart),
              ),
            ],
            onChanged: (v) {
              if (v != null) ctrl.setRightClick(v);
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.confirmMultilinePasteTitle),
          subtitle: Text(strings.confirmMultilinePasteDesc),
          value: s.confirmMultilinePaste,
          onChanged: ctrl.setConfirmMultilinePaste,
        ),
      ],
    );
  }
}
