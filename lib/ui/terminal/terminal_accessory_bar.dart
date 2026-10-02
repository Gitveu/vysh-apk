import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import '../theme/app_theme.dart';

/// Однострочная панель горячих клавиш терминала для мобильных устройств (как в Termux).
/// Размещается над клавиатурой и содержит ESC, TAB, CTRL, ALT, стрелки и частые символы.
class TerminalAccessoryBar extends StatefulWidget {
  const TerminalAccessoryBar({
    super.key,
    required this.terminal,
    required this.focusNode,
  });

  final Terminal terminal;
  final FocusNode focusNode;

  @override
  State<TerminalAccessoryBar> createState() => _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends State<TerminalAccessoryBar> {
  bool _ctrlActive = false;
  bool _altActive = false;

  void _sendKey(TerminalKey key) {
    HapticFeedback.lightImpact();
    widget.terminal.keyInput(
      key,
      ctrl: _ctrlActive,
      alt: _altActive,
    );
    if (_ctrlActive || _altActive) {
      setState(() {
        _ctrlActive = false;
        _altActive = false;
      });
    }
    _refocus();
  }

  void _sendText(String text) {
    HapticFeedback.lightImpact();
    if (_ctrlActive && text.length == 1) {
      final code = text.toUpperCase().codeUnitAt(0);
      if (code >= 64 && code <= 95) {
        widget.terminal.textInput(String.fromCharCode(code - 64));
      } else {
        widget.terminal.textInput(text);
      }
      setState(() => _ctrlActive = false);
    } else {
      widget.terminal.textInput(text);
    }
    if (_altActive) setState(() => _altActive = false);
    _refocus();
  }

  void _sendCtrlSequence(String char) {
    HapticFeedback.mediumImpact();
    final code = char.toUpperCase().codeUnitAt(0);
    if (code >= 64 && code <= 95) {
      widget.terminal.textInput(String.fromCharCode(code - 64));
    }
    setState(() => _ctrlActive = false);
    _refocus();
  }

  void _refocus() {
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  void _showCtrlMenu(BuildContext context) {
    HapticFeedback.selectionClick();
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Быстрые команды Ctrl',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const Divider(height: 12),
              _ctrlMenuItem(ctx, 'Ctrl+C', 'Прервать процесс (SIGINT)', () => _sendCtrlSequence('C')),
              _ctrlMenuItem(ctx, 'Ctrl+D', 'Выход / Конец ввода (EOF)', () => _sendCtrlSequence('D')),
              _ctrlMenuItem(ctx, 'Ctrl+Z', 'Приостановить в фон (SIGTSTP)', () => _sendCtrlSequence('Z')),
              _ctrlMenuItem(ctx, 'Ctrl+L', 'Очистить экран', () => _sendCtrlSequence('L')),
              _ctrlMenuItem(ctx, 'Ctrl+A', 'В начало строки', () => _sendCtrlSequence('A')),
              _ctrlMenuItem(ctx, 'Ctrl+E', 'В конец строки', () => _sendCtrlSequence('E')),
              _ctrlMenuItem(ctx, 'Ctrl+R', 'Поиск по истории команд', () => _sendCtrlSequence('R')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ctrlMenuItem(BuildContext ctx, String shortcut, String desc, VoidCallback onTap) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          shortcut,
          style: monoStyle(ctx, size: 12.5, color: Theme.of(ctx).colorScheme.onPrimaryContainer)
              .copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(desc, style: const TextStyle(fontSize: 13.5)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 0.7),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _KeyChip(
              label: 'ESC',
              onTap: () => _sendKey(TerminalKey.escape),
            ),
            _KeyChip(
              label: 'TAB',
              onTap: () => _sendKey(TerminalKey.tab),
            ),
            _KeyChip(
              label: 'CTRL',
              active: _ctrlActive,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _ctrlActive = !_ctrlActive);
                _refocus();
              },
              onLongPress: () => _showCtrlMenu(context),
            ),
            _KeyChip(
              label: 'ALT',
              active: _altActive,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _altActive = !_altActive);
                _refocus();
              },
            ),
            const _Divider(),
            _KeyChip(
              icon: Icons.arrow_upward,
              tooltip: 'Вверх',
              onTap: () => _sendKey(TerminalKey.arrowUp),
            ),
            _KeyChip(
              icon: Icons.arrow_downward,
              tooltip: 'Вниз',
              onTap: () => _sendKey(TerminalKey.arrowDown),
            ),
            _KeyChip(
              icon: Icons.arrow_back,
              tooltip: 'Влево',
              onTap: () => _sendKey(TerminalKey.arrowLeft),
            ),
            _KeyChip(
              icon: Icons.arrow_forward,
              tooltip: 'Вправо',
              onTap: () => _sendKey(TerminalKey.arrowRight),
            ),
            const _Divider(),
            _KeyChip(
              label: '/',
              onTap: () => _sendText('/'),
            ),
            _KeyChip(
              label: '-',
              onTap: () => _sendText('-'),
            ),
            _KeyChip(
              label: '~',
              onTap: () => _sendText('~'),
            ),
            _KeyChip(
              label: '|',
              onTap: () => _sendText('|'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({
    this.label,
    this.icon,
    this.tooltip,
    this.active = false,
    required this.onTap,
    this.onLongPress,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bg = active ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final borderColor = active ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4);

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(6),
        splashColor: scheme.primary.withValues(alpha: 0.2),
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: icon != null
              ? Icon(icon, size: 15, color: fg)
              : Text(
                  label!,
                  style: monoStyle(
                    context,
                    size: 11.5,
                    color: fg,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );

    if (tooltip != null) {
      content = Tooltip(message: tooltip!, child: content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: content,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }
}
