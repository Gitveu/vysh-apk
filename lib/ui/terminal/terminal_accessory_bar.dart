import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import '../../domain/models/app_strings.dart';
import '../../domain/services/terminal_session.dart';
import '../theme/app_theme.dart';

/// Однострочная панель горячих клавиш терминала для мобильных устройств (как в Termux).
/// Размещается над клавиатурой:
/// - Основная строка: ESC, CTRL, ALT, стрелки ↑ ↓ ← →, ^C и кнопка вызова «Расширенной панели».
/// - Расширенная панель: TAB, /, -, ~, |, Home, End, PgUp, PgDn, ^D, ^Z.
class TerminalAccessoryBar extends StatefulWidget {
  const TerminalAccessoryBar({
    super.key,
    required this.session,
    required this.focusNode,
    this.onToggleFiles,
    this.filesOpen = false,
  });

  final TerminalSession session;
  final FocusNode focusNode;
  final VoidCallback? onToggleFiles;
  final bool filesOpen;

  @override
  State<TerminalAccessoryBar> createState() => _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends State<TerminalAccessoryBar> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.session.onModifiersChanged = _onModifiersChanged;
  }

  @override
  void didUpdateWidget(covariant TerminalAccessoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.onModifiersChanged = null;
      widget.session.onModifiersChanged = _onModifiersChanged;
    }
  }

  @override
  void dispose() {
    if (widget.session.onModifiersChanged == _onModifiersChanged) {
      widget.session.onModifiersChanged = null;
    }
    super.dispose();
  }

  void _onModifiersChanged() {
    if (mounted) setState(() {});
  }

  void _sendKey(TerminalKey key) {
    HapticFeedback.lightImpact();
    widget.session.terminal.keyInput(
      key,
      ctrl: widget.session.ctrlModifier,
      alt: widget.session.altModifier,
    );
    widget.session.resetModifiers();
    _refocus();
  }

  void _sendDirect(String text) {
    HapticFeedback.lightImpact();
    widget.session.sendDirect(text);
    widget.session.resetModifiers();
    _refocus();
  }

  void _sendText(String text) {
    HapticFeedback.lightImpact();
    if (widget.session.ctrlModifier && text.length == 1) {
      final code = text.toUpperCase().codeUnitAt(0);
      if (code >= 64 && code <= 95) {
        widget.session.sendDirect(String.fromCharCode(code - 64));
      } else {
        widget.session.sendDirect(text);
      }
      widget.session.resetModifiers();
    } else {
      widget.session.terminal.textInput(text);
    }
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
    final strings = AppStrings.of(context);
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
                  strings.ctrlQuickTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const Divider(height: 12),
              _ctrlMenuItem(ctx, 'Ctrl+C', strings.ctrlCSigint, () => _sendDirect('\x03')),
              _ctrlMenuItem(ctx, 'Ctrl+U', strings.isRu ? 'Стереть строку ввода' : 'Erase input line', () => _sendDirect('\x15')),
              _ctrlMenuItem(ctx, 'Ctrl+D', strings.ctrlDEof, () => _sendDirect('\x04')),
              _ctrlMenuItem(ctx, 'Ctrl+Z', strings.ctrlZSuspend, () => _sendDirect('\x1a')),
              _ctrlMenuItem(ctx, 'Ctrl+L', strings.ctrlLClear, () => _sendDirect('\x0c')),
              _ctrlMenuItem(ctx, 'Ctrl+A', strings.ctrlABeginning, () => _sendDirect('\x01')),
              _ctrlMenuItem(ctx, 'Ctrl+E', strings.ctrlEEnd, () => _sendDirect('\x05')),
              _ctrlMenuItem(ctx, 'Ctrl+R', strings.ctrlRSearch, () => _sendDirect('\x12')),
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
    final strings = AppStrings.of(context);
    final ctrlActive = widget.session.ctrlModifier;
    final altActive = widget.session.altModifier;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35), width: 0.7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Расширенная панель (скрыта по умолчанию, открывается по кнопке ...)
          if (_isExpanded)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.6),
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2), width: 0.7),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KeyChip(
                      label: 'TAB',
                      onTap: () => _sendKey(TerminalKey.tab),
                    ),
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
                    const _Divider(),
                    _KeyChip(
                      label: 'HOME',
                      onTap: () => _sendKey(TerminalKey.home),
                    ),
                    _KeyChip(
                      label: 'END',
                      onTap: () => _sendKey(TerminalKey.end),
                    ),
                    _KeyChip(
                      label: 'PGUP',
                      onTap: () => _sendKey(TerminalKey.pageUp),
                    ),
                    _KeyChip(
                      label: 'PGDN',
                      onTap: () => _sendKey(TerminalKey.pageDown),
                    ),
                    const _Divider(),
                    _KeyChip(
                      label: '^U',
                      tooltip: strings.isRu ? 'Стереть строку (^U)' : 'Erase line (^U)',
                      onTap: () => _sendDirect('\x15'),
                    ),
                    _KeyChip(
                      icon: Icons.backspace_outlined,
                      tooltip: 'Backspace',
                      onTap: () => _sendKey(TerminalKey.backspace),
                    ),
                    _KeyChip(
                      label: '^D',
                      tooltip: 'EOF / Выход',
                      onTap: () => _sendDirect('\x04'),
                    ),
                    _KeyChip(
                      label: '^Z',
                      tooltip: strings.isRu ? 'Фон (SIGTSTP)' : 'Background (SIGTSTP)',
                      onTap: () => _sendDirect('\x1a'),
                    ),
                    if (widget.onToggleFiles != null) ...[
                      const _Divider(),
                      _KeyChip(
                        icon: widget.filesOpen ? Icons.terminal_rounded : Icons.folder_outlined,
                        label: 'SFTP',
                        tooltip: widget.filesOpen ? strings.console : strings.sftpPaneTitle,
                        active: widget.filesOpen,
                        onTap: widget.onToggleFiles!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Основная однострочная панель: ESC, CTRL, ALT, стрелки, ^C и переключатель
          SizedBox(
            height: 38,
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
                    label: 'CTRL',
                    active: ctrlActive,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.session.toggleCtrl();
                      _refocus();
                    },
                    onLongPress: () => _showCtrlMenu(context),
                  ),
                  _KeyChip(
                    label: 'ALT',
                    active: altActive,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.session.toggleAlt();
                      _refocus();
                    },
                  ),
                  const _Divider(),
                  _KeyChip(
                    icon: Icons.arrow_upward,
                    tooltip: strings.isRu ? 'Вверх' : 'Up',
                    onTap: () => _sendKey(TerminalKey.arrowUp),
                  ),
                  _KeyChip(
                    icon: Icons.arrow_downward,
                    tooltip: strings.isRu ? 'Вниз' : 'Down',
                    onTap: () => _sendKey(TerminalKey.arrowDown),
                  ),
                  _KeyChip(
                    icon: Icons.arrow_back,
                    tooltip: strings.isRu ? 'Влево' : 'Left',
                    onTap: () => _sendKey(TerminalKey.arrowLeft),
                  ),
                  _KeyChip(
                    icon: Icons.arrow_forward,
                    tooltip: strings.isRu ? 'Вправо' : 'Right',
                    onTap: () => _sendKey(TerminalKey.arrowRight),
                  ),
                  const _Divider(),
                  // Кнопка переключения расширенной панели
                  _KeyChip(
                    icon: _isExpanded ? Icons.expand_more : Icons.more_horiz,
                    tooltip: _isExpanded
                        ? (strings.isRu ? 'Скрыть панель' : 'Hide panel')
                        : (strings.isRu ? 'Расширенная панель (Tab, /, SFTP)' : 'Expanded panel (Tab, /, SFTP)'),
                    active: _isExpanded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isExpanded = !_isExpanded);
                      _refocus();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
