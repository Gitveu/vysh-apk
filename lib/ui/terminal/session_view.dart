import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm2/src/ui/render.dart';
import 'package:xterm2/xterm.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/session_tab.dart';
import '../../domain/services/external_colors_controller.dart';
import '../../domain/services/settings_controller.dart';
import '../../domain/services/tabs_controller.dart';
import '../../infra/platform/desktop_env.dart';
import '../shell/ui_state.dart';
import '../sftp/sftp_pane.dart';
import '../theme/app_theme.dart';
import 'connection_failure_view.dart';
import 'terminal_accessory_bar.dart';
import 'terminal_theme.dart';
import 'termux_menu.dart';

/// Вкладка сессии: терминал + контекстное меню Termux (зажатие пальцем, выбор текста/пустоты, copy/paste/cut).
class SessionView extends ConsumerStatefulWidget {
  const SessionView({super.key, required this.tab, required this.active});

  final SessionTab tab;
  final bool active;

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView> with WidgetsBindingObserver {
  final _controller = TerminalController();
  final _focus = FocusNode(debugLabel: 'terminal');
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  double _paneWidth = 420;
  bool _failureDismissed = false;
  bool _showLogManually = false;

  // Жесты Termux: зажатие пальцем, выделение текста или пустоты
  Timer? _longPressTimer;
  Offset? _touchStartLocal;
  Offset? _touchStartGlobal;
  bool _isSelecting = false;
  bool _selectionIsEmptiness = false;
  Offset? _termuxMenuPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onSelectionChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      final session = ref.read(tabsProvider.notifier).sessionOf(widget.tab.id);
      if (session != null &&
          widget.tab.status == SessionStatus.lost &&
          session.droppedAfterReady) {
        _reconnect();
      }
    }
  }

  @override
  void didUpdateWidget(SessionView old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
    if (widget.tab.status == SessionStatus.connecting &&
        old.tab.status != SessionStatus.connecting) {
      _failureDismissed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _longPressTimer?.cancel();
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Terminal? get _terminal =>
      ref.read(tabsProvider.notifier).sessionOf(widget.tab.id)?.terminal;

  RenderTerminal? get _renderTerminal {
    try {
      return _terminalViewKey.currentState?.renderTerminal;
    } catch (_) {
      return null;
    }
  }

  void _onSelectionChanged() {
    if (!ref.read(settingsProvider).copyOnSelect) return;
    _copySelection();
  }

  bool _copySelection() {
    final sel = _controller.selection;
    final terminal = _terminal;
    if (sel == null || terminal == null) return false;
    final text = terminal.buffer.getText(sel);
    if (text.isEmpty) return false;
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  int _getSelectedCharCount() {
    final sel = _controller.selection;
    final terminal = _terminal;
    if (sel == null || terminal == null) return 0;
    return terminal.buffer.getText(sel).length;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
      ),
    );
  }

  void _copy() {
    final sel = _controller.selection;
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);

    if (sel == null || terminal == null) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    final text = terminal.buffer.getText(sel);
    Clipboard.setData(ClipboardData(text: text));
    _controller.clearSelection();
    _showToast(strings.copiedToast(text.length));
    _dismissTermuxMenu();
  }

  void _cut() {
    final sel = _controller.selection;
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);

    if (sel == null || terminal == null) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    final text = terminal.buffer.getText(sel);
    Clipboard.setData(ClipboardData(text: text));

    // Отправляем в терминал сигнал очистки/удаления выделенного текста
    if (text.trim().isNotEmpty) {
      if (text.length <= 80 && !text.contains('\n')) {
        terminal.textInput(String.fromCharCodes(List.filled(text.length, 0x7f)));
      } else {
        terminal.textInput('\x15'); // Ctrl+U: очистить строку ввода
      }
    }

    _controller.clearSelection();
    _showToast(strings.cutToast(text.length));
    _dismissTermuxMenu();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    var text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;

    final lines = text.trimRight().split(RegExp(r'\r?\n'));
    if (lines.length > 1 && ref.read(settingsProvider).confirmMultilinePaste) {
      final ok = await _confirmPaste(lines);
      if (ok == null) {
        _focus.requestFocus();
        return;
      }
      if (ok == false) text = lines.join(' ');
    }
    _terminal?.paste(text);
    _controller.clearSelection();
    _focus.requestFocus();
    if (!mounted) return;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    _showToast(strings.pastedToast);
  }

  Future<bool?> _confirmPaste(List<String> lines) {
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final preview = lines.take(12).join('\n') + (lines.length > 12 ? '\n…' : '');
        return AlertDialog(
          icon: Icon(Icons.content_paste_go, color: scheme.primary),
          title: Text(strings.multilineTitle(lines.length)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(strings.multilineDesc),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(preview, style: monoStyle(context, size: 12.5)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.pasteSingleLine),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.pasteConfirm),
            ),
          ],
        );
      },
    );
  }

  void _selectAll() {
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    if (terminal == null) return;

    final lines = terminal.buffer.lines;
    if (lines.length == 0) return;

    // Выбираем только одну строчку полностью
    final rt = _renderTerminal;
    final touchPos = _touchStartLocal;
    bool selected = false;

    if (touchPos != null && rt != null) {
      final cellOffset = rt.getCellOffset(touchPos);
      final boundary = terminal.buffer.getLineBoundary(cellOffset);
      if (boundary != null) {
        _controller.setSelection(
          terminal.buffer.createAnchorFromOffset(boundary.begin),
          terminal.buffer.createAnchorFromOffset(boundary.end),
          mode: SelectionMode.line,
        );
        selected = true;
      }
    }

    if (!selected) {
      final currentSel = _controller.selection;
      if (currentSel != null) {
        final boundary = terminal.buffer.getLineBoundary(currentSel.begin);
        if (boundary != null) {
          _controller.setSelection(
            terminal.buffer.createAnchorFromOffset(boundary.begin),
            terminal.buffer.createAnchorFromOffset(boundary.end),
            mode: SelectionMode.line,
          );
          selected = true;
        }
      }
    }

    if (!selected) {
      final cursorY = terminal.buffer.absoluteCursorY.clamp(0, lines.length - 1);
      final boundary = terminal.buffer.getLineBoundary(CellOffset(0, cursorY));
      if (boundary != null) {
        _controller.setSelection(
          terminal.buffer.createAnchorFromOffset(boundary.begin),
          terminal.buffer.createAnchorFromOffset(boundary.end),
          mode: SelectionMode.line,
        );
      } else {
        final lineLen = lines[cursorY].length;
        _controller.setSelection(
          terminal.buffer.createAnchor(0, cursorY),
          terminal.buffer.createAnchor(lineLen, cursorY),
          mode: SelectionMode.line,
        );
      }
    }

    _selectionIsEmptiness = false;
    _showToast(strings.selectLineToast);
    setState(() {});
  }

  void _share() {
    final sel = _controller.selection;
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    final text = (sel != null && terminal != null) ? terminal.buffer.getText(sel) : '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      _showToast(strings.copiedToast(text.length));
    } else {
      _showToast(strings.nothingToCopy);
    }
    _dismissTermuxMenu();
  }

  void _reset() {
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    terminal?.keyInput(TerminalKey.keyC, ctrl: true);
    _controller.clearSelection();
    _showToast(strings.resetToast);
    _dismissTermuxMenu();
  }

  void _clear() {
    final terminal = _terminal;
    final strings = TermuxStrings.of(context, ref.read(settingsProvider).language);
    terminal?.keyInput(TerminalKey.keyL, ctrl: true);
    _controller.clearSelection();
    _showToast(strings.clearToast);
    _dismissTermuxMenu();
  }

  void _showTermuxMenu(Offset position) {
    setState(() {
      _termuxMenuPosition = position;
    });
  }

  void _dismissTermuxMenu() {
    if (_termuxMenuPosition != null) {
      setState(() {
        _termuxMenuPosition = null;
      });
      _focus.requestFocus();
    }
  }

  void _onSecondaryClick(Offset position, [Offset? localPosition]) {
    final action = ref.read(settingsProvider).rightClick;
    if (HardwareKeyboard.instance.isShiftPressed || action == RightClickAction.menu) {
      _showTermuxMenu(localPosition ?? position);
      return;
    }
    if (action == RightClickAction.smart && _controller.selection != null) {
      _copySelection();
      _controller.clearSelection();
      return;
    }
    _paste();
  }

  // --- Обработка удержания пальца (Termux Long Press) ---
  void _onPointerDown(PointerDownEvent e) {
    if (ref.read(settingsProvider).middleClickPaste &&
        (e.buttons & kMiddleMouseButton) != 0) {
      _paste();
      return;
    }

    // Правый клик мыши
    if ((e.buttons & kSecondaryMouseButton) != 0) {
      _onSecondaryClick(e.position, e.localPosition);
      return;
    }

    _touchStartLocal = e.localPosition;
    _touchStartGlobal = e.position;
    _isSelecting = false;

    _longPressTimer?.cancel();
    // 380 мс — комфортный порог зажатия пальцем (long press), как в Termux
    _longPressTimer = Timer(const Duration(milliseconds: 380), _onLongPressTriggered);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_longPressTimer?.isActive == true) {
      final startGlobal = _touchStartGlobal;
      if (startGlobal != null && (e.position - startGlobal).distance > 16.0) {
        // Палец сдвинулся — это прокрутка терминала, отменяем long press
        _longPressTimer?.cancel();
        _longPressTimer = null;
      }
    } else if (_isSelecting) {
      // Пользователь зажал палец и теперь тянет, выбирая область текста или пустоты
      final startLocal = _touchStartLocal;
      final rt = _renderTerminal;
      if (startLocal != null && rt != null) {
        if (_selectionIsEmptiness) {
          rt.selectCharacters(startLocal, e.localPosition);
        } else {
          rt.selectWord(startLocal, e.localPosition);
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _longPressTimer?.cancel();
    _longPressTimer = null;

    if (_isSelecting) {
      _isSelecting = false;
      // Открываем меню Termux в точке отпускания пальца
      _showTermuxMenu(e.localPosition);
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _isSelecting = false;
  }

  void _onLongPressTriggered() {
    final startLocal = _touchStartLocal;
    final terminal = _terminal;
    final rt = _renderTerminal;
    if (startLocal == null || terminal == null || rt == null) return;

    HapticFeedback.mediumImpact();

    final cellOffset = rt.getCellOffset(startLocal);
    final wordBoundary = terminal.buffer.getWordBoundary(cellOffset);
    final wordText = wordBoundary != null ? terminal.buffer.getText(wordBoundary, true) : '';

    if (wordText.trim().isNotEmpty) {
      // Пользователь зажал текст — выделяем слово
      _selectionIsEmptiness = false;
      rt.selectWord(startLocal);
    } else {
      // Пользователь зажал пустоту (пустую строку, пробелы, пустое пространство терминала)
      _selectionIsEmptiness = true;
      rt.selectCharacters(startLocal);
    }

    _isSelecting = true;
    setState(() {
      _termuxMenuPosition = null;
    });
  }

  Map<ShortcutActivator, Intent> _shortcuts(bool ctrlV) {
    final map = <ShortcutActivator, Intent>{
      for (final e in defaultTerminalShortcuts.entries)
        if (e.value is! PasteTextIntent) e.key: e.value,
      const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): const _PasteIntent(),
      const SingleActivator(LogicalKeyboardKey.insert, shift: true): const _PasteIntent(),
    };
    if (ctrlV) {
      map[const SingleActivator(LogicalKeyboardKey.keyV, control: true)] = const _PasteIntent();
    }
    return map;
  }

  void _reconnect() {
    setState(() => _showLogManually = false);
    ref.read(tabsProvider.notifier).reconnect(widget.tab.id);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.read(tabsProvider.notifier).sessionOf(widget.tab.id);
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final paneOpen = ref.watch(sftpPaneProvider).contains(widget.tab.id);
    final ext = ref.watch(externalColorsProvider);
    final strings = TermuxStrings.of(context, settings.language);

    if (session == null) return const SizedBox.shrink();

    final showFailure = _showLogManually ||
        (widget.tab.status == SessionStatus.lost &&
            session.lastFailure != null &&
            !_failureDismissed);

    final terminalView = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Actions(
        actions: {
          _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) {
            _paste();
            return null;
          }),
        },
        child: TerminalView(
          session.terminal,
          key: _terminalViewKey,
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          shortcuts: _shortcuts(settings.ctrlVPaste),
          theme: terminalThemeFor(scheme, ext),
          textStyle: TerminalStyle(
            fontSize: settings.terminalFontSize,
            fontFamily: monoFontFamily,
            fontFamilyFallback: monoFontFallback,
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          onSecondaryTapDown: (details, _) => _onSecondaryClick(
            details.globalPosition,
            details.localPosition,
          ),
        ),
      ),
    );

    final isCompact = MediaQuery.sizeOf(context).width < 650 || DesktopEnv.isMobile;

    final terminalArea = ColoredBox(
      color: terminalBackgroundFor(scheme, ext),
      child: Stack(
        children: [
          Positioned.fill(child: terminalView),
          if (showFailure)
            Positioned.fill(
              child: ConnectionFailureView(
                session: session,
                onReconnect: _reconnect,
                onDismiss: () {
                  setState(() {
                    _failureDismissed = true;
                    _showLogManually = false;
                  });
                  _focus.requestFocus();
                },
              ),
            ),
          // Всплывающее меню Termux
          if (_termuxMenuPosition != null)
            TermuxFloatingMenu(
              position: _termuxMenuPosition!,
              hasSelection: _controller.selection != null,
              isEmptySpace: _selectionIsEmptiness,
              selectedCharCount: _getSelectedCharCount(),
              strings: strings,
              onCopy: _copy,
              onPaste: () {
                _dismissTermuxMenu();
                _paste();
              },
              onCut: _cut,
              onSelectAll: _selectAll,
              onShare: _share,
              onReset: _reset,
              onClear: _clear,
              onLog: () {
                _dismissTermuxMenu();
                setState(() => _showLogManually = true);
              },
              onReconnect: () {
                _dismissTermuxMenu();
                _reconnect();
              },
              onDismiss: _dismissTermuxMenu,
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 2,
          child: widget.tab.status == SessionStatus.connecting
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(
          child: isCompact
              ? IndexedStack(
                  index: paneOpen ? 1 : 0,
                  children: [
                    terminalArea,
                    SftpPane(tab: widget.tab, active: widget.active && paneOpen),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: terminalArea),
                    if (paneOpen) ...[
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (d) => setState(() {
                            final max = MediaQuery.sizeOf(context).width * 0.7;
                            _paneWidth =
                                (_paneWidth - d.delta.dx).clamp(260, max < 260 ? 260 : max).toDouble();
                          }),
                          child: Container(width: 5, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                      ),
                      SizedBox(
                        width: _paneWidth,
                        child: SftpPane(tab: widget.tab, active: widget.active),
                      ),
                    ],
                  ],
                ),
        ),
        if (settings.showAccessoryBar && (!isCompact || !paneOpen))
          TerminalAccessoryBar(
            session: session,
            focusNode: _focus,
          ),
        _StatusBar(
          tab: widget.tab,
          serverVersion: session.serverVersion,
          filesOpen: paneOpen,
          onToggleFiles: () => ref.read(sftpPaneProvider.notifier).toggle(widget.tab.id),
          onReconnect: _reconnect,
          strings: strings,
        ),
      ],
    );
  }
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.tab,
    required this.serverVersion,
    required this.onReconnect,
    required this.filesOpen,
    required this.onToggleFiles,
    required this.strings,
  });

  final SessionTab tab;
  final String? serverVersion;
  final VoidCallback onReconnect;
  final bool filesOpen;
  final VoidCallback onToggleFiles;
  final TermuxStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 650 || DesktopEnv.isMobile;
    final style = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final (status, color) = switch (tab.status) {
      SessionStatus.connecting => (strings.isRussian ? 'Подключение…' : 'Connecting…', scheme.tertiary),
      SessionStatus.ready => (strings.isRussian ? 'Подключено' : 'Connected', Colors.green.shade500),
      SessionStatus.lost => (strings.isRussian ? 'Нет соединения' : 'Connection lost', scheme.error),
      SessionStatus.closed => (strings.isRussian ? 'Сессия завершена' : 'Session closed', scheme.outline),
    };

    return Container(
      height: 32,
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(status, style: style),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tab.host.displayAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (!isCompact && serverVersion != null && tab.status == SessionStatus.ready) ...[
            const SizedBox(width: 16),
            Flexible(
              child: Text(serverVersion!,
                  overflow: TextOverflow.ellipsis,
                  style: style?.copyWith(color: scheme.outline)),
            ),
          ],
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: theme.textTheme.bodySmall,
              foregroundColor: filesOpen ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: onToggleFiles,
            icon: Icon(
              filesOpen
                  ? (isCompact ? Icons.terminal_rounded : Icons.folder_open)
                  : Icons.folder_outlined,
              size: 14,
            ),
            label: Text(
              isCompact
                  ? (filesOpen
                      ? (strings.isRussian ? 'Консоль' : 'Console')
                      : (strings.isRussian ? 'Файлы' : 'Files'))
                  : (DesktopEnv.isDesktop
                      ? (strings.isRussian ? 'Файлы  Ctrl+Shift+E' : 'Files  Ctrl+Shift+E')
                      : (strings.isRussian ? 'Файлы' : 'Files')),
            ),
          ),
          if (tab.status != SessionStatus.connecting) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.bodySmall,
              ),
              onPressed: onReconnect,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(
                isCompact
                    ? (strings.isRussian ? 'Переподкл.' : 'Reconnect')
                    : (strings.isRussian ? 'Переподключить' : 'Reconnect'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
