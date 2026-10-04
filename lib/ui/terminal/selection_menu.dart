import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/app_settings.dart';

/// Локализованные строки для контекстного меню keyboard на русском и английском.
class SelectionStrings {
  const SelectionStrings({required this.isRussian});

  final bool isRussian;

  static SelectionStrings of(
    BuildContext context, [
    AppLanguage language = AppLanguage.auto,
  ]) {
    if (language == AppLanguage.ru) {
      return const SelectionStrings(isRussian: true);
    }
    if (language == AppLanguage.en) {
      return const SelectionStrings(isRussian: false);
    }

    final loc =
        Localizations.maybeLocaleOf(context) ??
        (ui.PlatformDispatcher.instance.locales.isNotEmpty
            ? ui.PlatformDispatcher.instance.locales.first
            : ui.PlatformDispatcher.instance.locale);
    final code = loc.languageCode.toLowerCase();
    final isRu =
        code.startsWith('ru') || code.startsWith('be') || code.startsWith('uk');

    return SelectionStrings(isRussian: isRu);
  }

  String get copy => isRussian ? 'Копировать' : 'Copy';
  String get paste => isRussian ? 'Вставить' : 'Paste';
  String get cut => isRussian ? 'Вырезать' : 'Cut';

  String get selectLine => isRussian ? 'Выбрать строку' : 'Select line';
  String get selectAll => selectLine;
  String get eraseLine => isRussian ? 'Стереть строку' : 'Erase line';

  String get share => isRussian ? 'Поделиться' : 'Share';
  String get reset => isRussian ? 'Сброс (^C)' : 'Reset (^C)';
  String get clear => isRussian ? 'Очистить (^L)' : 'Clear (^L)';
  String get sftp => isRussian ? 'Файлы (SFTP)' : 'Files (SFTP)';
  String get log => isRussian ? 'Журнал' : 'Log';
  String get reconnect => isRussian ? 'Переподключить' : 'Reconnect';
  String get deselect => isRussian ? 'Снять выделение' : 'Deselect';
  String get more => isRussian ? 'Ещё' : 'More';
  String get terminal => isRussian ? 'Терминал' : 'Terminal';
  String get emptyArea => isRussian ? 'Терминал' : 'Terminal';
  String get selectedText => isRussian ? 'Текст' : 'Text';

  String charCount(int count) => isRussian ? '$count симв.' : '$count chars';

  String copiedToast(int count) => isRussian
      ? 'Скопировано в буфер ($count симв.)'
      : 'Copied to clipboard ($count chars)';

  String cutToast(int count) => isRussian
      ? 'Вырезано в буфер ($count симв.)'
      : 'Cut to clipboard ($count chars)';

  String get pastedToast => isRussian ? 'Вставлено' : 'Pasted';

  String get nothingToCopy =>
      isRussian ? 'Нет текста для копирования' : 'No text to copy';

  String get resetToast => isRussian
      ? 'Отправлен сигнал прерывания (^C)'
      : 'Interrupt signal sent (^C)';

  String get clearToast => isRussian ? 'Экран очищен' : 'Screen cleared';

  String multilineTitle(int count) =>
      isRussian ? 'Вставить $count строк?' : 'Paste $count lines?';

  String get multilineDesc => isRussian
      ? 'Каждая строка выполнится как отдельная команда.'
      : 'Each line will execute as a separate command.';

  String get cancel => isRussian ? 'Отмена' : 'Cancel';

  String get pasteSingleLine => isRussian ? 'Одной строкой' : 'Single line';

  String get pasteConfirm => isRussian ? 'Вставить' : 'Paste';
}

/// Контекстное всплывающее меню в стиле keyboard.
class SelectionMenu extends StatefulWidget {
  const SelectionMenu({
    super.key,
    required this.position,
    required this.hasSelection,
    required this.isEmptySpace,
    required this.selectedCharCount,
    required this.strings,
    required this.onCopy,
    required this.onPaste,
    required this.onCut,
    required this.onSelectAll,
    this.onErase,
    required this.onShare,
    required this.onReset,
    required this.onClear,
    this.onSftp,
    required this.onLog,
    required this.onReconnect,
    required this.onDismiss,
  });

  final Offset position;
  final bool hasSelection;
  final bool isEmptySpace;
  final int selectedCharCount;
  final SelectionStrings strings;

  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onCut;
  final VoidCallback onSelectAll;
  final VoidCallback? onErase;
  final VoidCallback onShare;
  final VoidCallback onReset;
  final VoidCallback onClear;
  final VoidCallback? onSftp;
  final VoidCallback onLog;
  final VoidCallback onReconnect;
  final VoidCallback onDismiss;

  @override
  State<SelectionMenu> createState() => _SelectionMenuState();
}

class _SelectionMenuState extends State<SelectionMenu> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = widget.strings;

    final hasValidSelection =
        widget.hasSelection &&
        widget.selectedCharCount > 0 &&
        !widget.isEmptySpace;

    final surfaceColor = ElevationOverlay.applySurfaceTint(
      scheme.surfaceContainerHighest,
      scheme.surfaceTint,
      6,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxMenuWidth = math.max(0.0, constraints.maxWidth - 20);
        final menuWidth = math.min(_expanded ? 320.0 : 300.0, maxMenuWidth);
        final halfWidth = menuWidth / 2;

        var left = widget.position.dx - halfWidth;
        final maxLeft = math.max(10.0, constraints.maxWidth - menuWidth - 10);
        left = left.clamp(10.0, maxLeft).toDouble();

        final estimatedHeight = _expanded ? 210.0 : 110.0;
        final top = (widget.position.dy - estimatedHeight - 8)
            .clamp(
              10.0,
              math.max(10.0, constraints.maxHeight - estimatedHeight - 10),
            )
            .toDouble();

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.6),
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh.withValues(
                            alpha: 0.8,
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasValidSelection
                                  ? Icons.text_fields_rounded
                                  : Icons.terminal_rounded,
                              size: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasValidSelection
                                    ? '${strings.selectedText} '
                                          '(${strings.charCount(widget.selectedCharCount)})'
                                    : strings.terminal,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: widget.onDismiss,
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.copy_rounded,
                                label: strings.copy,
                                onTap: widget.onCopy,
                              ),
                            ),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.paste_rounded,
                                label: strings.paste,
                                onTap: widget.onPaste,
                              ),
                            ),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.content_cut_rounded,
                                label: strings.cut,
                                onTap: widget.onCut,
                              ),
                            ),
                            Expanded(
                              child: _ActionButton(
                                icon: _expanded
                                    ? Icons.expand_less_rounded
                                    : Icons.more_horiz_rounded,
                                label: strings.more,
                                onTap: () {
                                  setState(() {
                                    _expanded = !_expanded;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_expanded) ...[
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              _SecondaryButton(
                                icon: Icons.select_all_rounded,
                                label: strings.selectAll,
                                onTap: widget.onSelectAll,
                              ),
                              if (widget.onErase != null)
                                _SecondaryButton(
                                  icon: Icons.backspace_outlined,
                                  label: strings.eraseLine,
                                  onTap: widget.onErase!,
                                ),
                              _SecondaryButton(
                                icon: Icons.share_rounded,
                                label: strings.share,
                                onTap: widget.onShare,
                              ),
                              _SecondaryButton(
                                icon: Icons.restart_alt_rounded,
                                label: strings.reset,
                                onTap: widget.onReset,
                              ),
                              _SecondaryButton(
                                icon: Icons.cleaning_services_rounded,
                                label: strings.clear,
                                onTap: widget.onClear,
                              ),
                              _SecondaryButton(
                                icon: Icons.refresh_rounded,
                                label: strings.reconnect,
                                onTap: widget.onReconnect,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
