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
import '../sftp/sftp_pane.dart';
import '../shell/ui_state.dart';
import '../theme/app_theme.dart';
import 'connection_failure_view.dart';
import 'terminal_accessory_bar.dart';
import 'terminal_theme.dart';
import 'termux_menu.dart';

/// Вкладка сессии: терминал и контекстное меню Termux.
class SessionView extends ConsumerStatefulWidget {
  const SessionView({super.key, required this.tab, required this.active});

  final SessionTab tab;
  final bool active;

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView>
    with WidgetsBindingObserver {
  final _controller = TerminalController();
  final _focus = FocusNode(debugLabel: 'terminal');
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  final _terminalStackKey = GlobalKey();
  final _scrollController = ScrollController();

  double _paneWidth = 420;

  bool _failureDismissed = false;
  bool _showLogManually = false;

  Timer? _longPressTimer;
  Offset? _touchStartLocal;
  Offset? _touchStartGlobal;

  bool _isSelecting = false;
  bool _selectionIsEmptiness = false;

  bool _isDraggingHandle = false;
  bool? _draggingStartHandle;
  CellOffset? _dragFixedCell;
  Offset? _dragTouchDeltaToTextPoint;

  Offset? _termuxMenuPosition;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onSelectionChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
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
        if (mounted) {
          _focus.requestFocus();
        }
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
    _scrollController.removeListener(_onScrollChanged);

    _scrollController.dispose();
    _controller.dispose();
    _focus.dispose();

    super.dispose();
  }

  Terminal? get _terminal {
    return ref.read(tabsProvider.notifier).sessionOf(widget.tab.id)?.terminal;
  }

  RenderTerminal? get _renderTerminal {
    try {
      return _terminalViewKey.currentState?.renderTerminal;
    } catch (_) {
      return null;
    }
  }

  void _onSelectionChanged() {
    if (mounted) {
      setState(() {});
    }

    if (_isDraggingHandle) {
      return;
    }

    if (!ref.read(settingsProvider).copyOnSelect) {
      return;
    }

    _copySelection();
  }

  void _onScrollChanged() {
    if (_controller.selection != null && mounted) {
      setState(() {});
    }
  }

  bool _copySelection() {
    final selection = _controller.selection;
    final terminal = _terminal;

    if (selection == null || terminal == null) {
      return false;
    }

    final text = terminal.buffer.getText(selection);

    if (text.isEmpty) {
      return false;
    }

    Clipboard.setData(ClipboardData(text: text));

    return true;
  }

  int _getSelectedCharCount() {
    final selection = _controller.selection;
    final terminal = _terminal;

    if (selection == null || terminal == null) {
      return 0;
    }

    return terminal.buffer.getText(selection).length;
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }

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
    final selection = _controller.selection;
    final terminal = _terminal;
    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    if (selection == null || terminal == null) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    final text = terminal.buffer.getText(selection);

    if (text.isEmpty) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    Clipboard.setData(ClipboardData(text: text));

    _controller.clearSelection();
    _dismissTermuxMenu();
  }

  void _cut() {
    final selection = _controller.selection;
    final terminal = _terminal;
    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    if (selection == null || terminal == null) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    final text = terminal.buffer.getText(selection);

    if (text.isEmpty) {
      _showToast(strings.nothingToCopy);
      _dismissTermuxMenu();
      return;
    }

    Clipboard.setData(ClipboardData(text: text));

    // Удаляем клиентский ввод без анализа содержимого терминала.
    if (text.trim().isNotEmpty) {
      if (text.length <= 80 && !text.contains('\n')) {
        terminal.textInput(
          String.fromCharCodes(List.filled(text.length, 0x7f)),
        );
      } else {
        terminal.textInput('\x15');
      }
    }

    _controller.clearSelection();
    _dismissTermuxMenu();
  }

  void _eraseCurrentSelectionOrLine() {
    final session = ref.read(tabsProvider.notifier).sessionOf(widget.tab.id);

    final terminal = session?.terminal;

    if (session == null || terminal == null) {
      _dismissTermuxMenu();
      return;
    }

    _controller.clearSelection();

    // Ctrl+U очищает текущий пользовательский ввод shell.
    terminal.textInput('\x15');

    _dismissTermuxMenu();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    var text = data?.text;

    if (text == null || text.isEmpty || !mounted) {
      return;
    }

    final lines = text.trimRight().split(RegExp(r'\r?\n'));

    if (lines.length > 1 && ref.read(settingsProvider).confirmMultilinePaste) {
      final ok = await _confirmPaste(lines);

      if (ok == null) {
        _focus.requestFocus();
        return;
      }

      if (ok == false) {
        text = lines.join(' ');
      }
    }

    _terminal?.paste(text);
    _controller.clearSelection();
    _focus.requestFocus();

    if (!mounted) {
      return;
    }

    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    _showToast(strings.pastedToast);
  }

  Future<bool?> _confirmPaste(List<String> lines) {
    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    return showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;

        final preview =
            lines.take(12).join('\n') + (lines.length > 12 ? '\n…' : '');

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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
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

  /// Выделяет только клиентский ввод пользователя.
  ///
  /// Никакого поиска текста в терминальном буфере нет.
  /// Prompt, вывод shell и ранее выполненные команды не выделяются.
  void _selectAll() {
    final session = ref.read(tabsProvider.notifier).sessionOf(widget.tab.id);

    final terminal = session?.terminal;

    if (session == null || terminal == null) {
      _dismissTermuxMenu();
      return;
    }

    final clientTypedCommand = session.clientTypedCommand;

    if (clientTypedCommand.isEmpty) {
      _controller.clearSelection();
      _selectionIsEmptiness = false;
      _dismissTermuxMenu();
      return;
    }

    final buffer = terminal.buffer;
    final lines = buffer.lines;

    if (lines.length == 0) {
      _controller.clearSelection();
      _selectionIsEmptiness = false;
      _dismissTermuxMenu();
      return;
    }

    final cursorY = buffer.absoluteCursorY.clamp(0, lines.length - 1).toInt();

    final cursorX = buffer.cursorX;

    // Клиентский ввод находится непосредственно перед курсором.
    // Текст prompt и вывод терминала здесь не анализируются.
    final startX = (cursorX - clientTypedCommand.length)
        .clamp(0, cursorX)
        .toInt();

    if (startX >= cursorX) {
      _controller.clearSelection();
      _selectionIsEmptiness = false;
      _dismissTermuxMenu();
      return;
    }

    _controller.setSelection(
      buffer.createAnchor(startX, cursorY),
      buffer.createAnchor(cursorX, cursorY),
    );

    _selectionIsEmptiness = false;
    _dismissTermuxMenu();
  }

  void _share() {
    final selection = _controller.selection;
    final terminal = _terminal;

    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    final text = selection != null && terminal != null
        ? terminal.buffer.getText(selection)
        : '';

    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    } else {
      _showToast(strings.nothingToCopy);
    }

    _dismissTermuxMenu();
  }

  void _reset() {
    final terminal = _terminal;

    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    terminal?.keyInput(TerminalKey.keyC, ctrl: true);

    _controller.clearSelection();
    _showToast(strings.resetToast);
    _dismissTermuxMenu();
  }

  void _clear() {
    final terminal = _terminal;

    final strings = TermuxStrings.of(
      context,
      ref.read(settingsProvider).language,
    );

    terminal?.keyInput(TerminalKey.keyL, ctrl: true);

    _controller.clearSelection();
    _showToast(strings.clearToast);
    _dismissTermuxMenu();
  }

  void _onHandlePanStart(DragStartDetails details, {required bool start}) {
    final selection = _controller.selection;
    final renderTerminal = _renderTerminal;
    final terminal = _terminal;
    if (selection == null || renderTerminal == null || terminal == null) return;

    _dismissTermuxMenu();

    final range = selection.normalized;
    _isDraggingHandle = true;
    _draggingStartHandle = start;

    _dragFixedCell = start ? range.end : range.begin;
    final movingCell = start ? range.begin : range.end;

    final cellOffset = renderTerminal.getOffset(movingCell);
    final textPoint = cellOffset + Offset(0, renderTerminal.cellSize.height);

    final touchInTerminal = renderTerminal.globalToLocal(details.globalPosition);
    _dragTouchDeltaToTextPoint = touchInTerminal - textPoint;
  }

  void _onHandlePanUpdate(DragUpdateDetails details, {required bool start}) {
    final renderTerminal = _renderTerminal;
    final terminal = _terminal;
    final fixedCell = _dragFixedCell;
    final delta = _dragTouchDeltaToTextPoint;

    if (renderTerminal == null ||
        terminal == null ||
        fixedCell == null ||
        delta == null ||
        !_isDraggingHandle ||
        _draggingStartHandle != start) {
      return;
    }

    final stackBox =
        _terminalStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && _scrollController.hasClients) {
      final localInStack = stackBox.globalToLocal(details.globalPosition);
      if (localInStack.dy < 40 && _scrollController.offset > 0) {
        _scrollController.jumpTo((_scrollController.offset - 20)
            .clamp(0.0, _scrollController.position.maxScrollExtent));
      } else if (localInStack.dy > stackBox.size.height - 40 &&
          _scrollController.offset < _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo((_scrollController.offset + 20)
            .clamp(0.0, _scrollController.position.maxScrollExtent));
      }
    }

    final touchInTerminal = renderTerminal.globalToLocal(details.globalPosition);
    final targetPointInTerminal = touchInTerminal - delta;

    final cell = renderTerminal.cellSize;
    final samplePoint = Offset(
      targetPointInTerminal.dx,
      targetPointInTerminal.dy - cell.height * 0.5,
    );

    final rawCell = renderTerminal.getCellOffset(samplePoint);
    final maxRow = terminal.buffer.lines.length - 1;
    if (maxRow < 0) return;

    final clampedRow = rawCell.y.clamp(0, maxRow);
    final maxCol = terminal.viewWidth;
    final clampedCol = rawCell.x.clamp(0, maxCol < 1 ? 0 : maxCol - 1);

    final movingCell = CellOffset(clampedCol, clampedRow);
    final buffer = terminal.buffer;

    if (start) {
      if (movingCell.isBefore(fixedCell)) {
        _controller.setSelection(
          buffer.createAnchorFromOffset(movingCell),
          buffer.createAnchorFromOffset(fixedCell),
        );
      } else {
        final endCol = (movingCell.x + 1).clamp(0, maxCol);
        _controller.setSelection(
          buffer.createAnchorFromOffset(fixedCell),
          buffer.createAnchor(endCol, movingCell.y),
        );
      }
    } else {
      if (movingCell.isAfterOrSame(fixedCell)) {
        final endCol = (movingCell.x + 1).clamp(0, maxCol);
        _controller.setSelection(
          buffer.createAnchorFromOffset(fixedCell),
          buffer.createAnchor(endCol, movingCell.y),
        );
      } else {
        final endCol = (fixedCell.x + 1).clamp(0, maxCol);
        _controller.setSelection(
          buffer.createAnchorFromOffset(movingCell),
          buffer.createAnchor(endCol, fixedCell.y),
        );
      }
    }
  }

  void _onHandlePanEnd(DragEndDetails details, {required bool start}) {
    _isDraggingHandle = false;
    _draggingStartHandle = null;
    _dragFixedCell = null;
    _dragTouchDeltaToTextPoint = null;

    if (ref.read(settingsProvider).copyOnSelect) {
      _copySelection();
    }

    if (mounted && _controller.selection != null) {
      final renderTerminal = _renderTerminal;
      final stackBox =
          _terminalStackKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderTerminal != null && stackBox != null) {
        final range = _controller.selection!.normalized;
        final endOffset = renderTerminal.getOffset(range.end);
        final globalPos = renderTerminal.localToGlobal(endOffset);
        final stackPos = stackBox.globalToLocal(globalPos);
        _showTermuxMenu(stackPos);
      }
    }
  }

  void _onHandlePanCancel({required bool start}) {
    _isDraggingHandle = false;
    _draggingStartHandle = null;
    _dragFixedCell = null;
    _dragTouchDeltaToTextPoint = null;
  }

  Widget _selectionHandle({required bool start}) {
    final renderTerminal = _renderTerminal;
    final selection = _controller.selection;
    final terminal = _terminal;
    if (renderTerminal == null || selection == null || terminal == null) {
      return const SizedBox.shrink();
    }

    final stackBox =
        _terminalStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) {
      return const SizedBox.shrink();
    }

    final range = selection.normalized;
    final anchorCell = start ? range.begin : range.end;

    if (anchorCell.y < 0 || anchorCell.y >= terminal.buffer.lines.length) {
      return const SizedBox.shrink();
    }

    final cell = renderTerminal.cellSize;
    final handleType = start
        ? TextSelectionHandleType.left
        : TextSelectionHandleType.right;

    final cellOffsetLocal = renderTerminal.getOffset(anchorCell);
    final textPointLocal = cellOffsetLocal + Offset(0, cell.height);

    final textPointGlobal = renderTerminal.localToGlobal(textPointLocal);
    final textPointInStack = stackBox.globalToLocal(textPointGlobal);

    const double touchSize = 48.0;
    const double handleSize = 22.0;
    const double pad = (touchSize - handleSize) / 2.0;

    final handleAnchor = MaterialTextSelectionControls().getHandleAnchor(
      handleType,
      cell.height,
    );

    final left = textPointInStack.dx - handleAnchor.dx - pad;
    final top = textPointInStack.dy - handleAnchor.dy - pad;

    return Positioned(
      key: ValueKey(start ? 'selection_handle_start' : 'selection_handle_end'),
      left: left,
      top: top,
      width: touchSize,
      height: touchSize,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          PanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(
              debugOwner: this,
              supportedDevices: <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.unknown,
                PointerDeviceKind.mouse,
              },
            ),
            (PanGestureRecognizer instance) {
              instance
                ..dragStartBehavior = DragStartBehavior.down
                ..gestureSettings = const DeviceGestureSettings(touchSlop: 1.0)
                ..onStart = (details) {
                  _onHandlePanStart(details, start: start);
                }
                ..onUpdate = (details) {
                  _onHandlePanUpdate(details, start: start);
                }
                ..onEnd = (details) {
                  _onHandlePanEnd(details, start: start);
                }
                ..onCancel = () {
                  _onHandlePanCancel(start: start);
                };
            },
          ),
        },
        child: Padding(
          padding: const EdgeInsets.all(pad),
          child: MaterialTextSelectionControls().buildHandle(
            context,
            handleType,
            cell.height,
          ),
        ),
      ),
    );
  }

  void _showTermuxMenu(Offset position) {
    setState(() {
      _termuxMenuPosition = position;
    });
  }

  void _dismissTermuxMenu() {
    if (_termuxMenuPosition == null) {
      return;
    }

    setState(() {
      _termuxMenuPosition = null;
    });

    _focus.requestFocus();
  }

  void _onSecondaryClick(Offset position, [Offset? localPosition]) {
    final action = ref.read(settingsProvider).rightClick;

    if (HardwareKeyboard.instance.isShiftPressed ||
        action == RightClickAction.menu) {
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

  void _onPointerDown(PointerDownEvent event) {
    if (ref.read(settingsProvider).middleClickPaste &&
        (event.buttons & kMiddleMouseButton) != 0) {
      _paste();
      return;
    }

    if ((event.buttons & kSecondaryMouseButton) != 0) {
      _onSecondaryClick(event.position, event.localPosition);
      return;
    }

    _touchStartLocal = event.localPosition;
    _touchStartGlobal = event.position;
    _isSelecting = false;

    _longPressTimer?.cancel();

    _longPressTimer = Timer(
      const Duration(milliseconds: 380),
      _onLongPressTriggered,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_longPressTimer?.isActive == true) {
      final startGlobal = _touchStartGlobal;

      if (startGlobal != null &&
          (event.position - startGlobal).distance > 16.0) {
        _longPressTimer?.cancel();
        _longPressTimer = null;
      }
    } else if (_isSelecting) {
      final startLocal = _touchStartLocal;
      final renderTerminal = _renderTerminal;

      if (startLocal != null && renderTerminal != null) {
        renderTerminal.selectCharacters(startLocal, event.localPosition);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    _longPressTimer = null;

    if (_isSelecting) {
      _isSelecting = false;
      final stackBox =
          _terminalStackKey.currentContext?.findRenderObject() as RenderBox?;
      final pos = stackBox != null
          ? stackBox.globalToLocal(event.position)
          : event.localPosition;
      _showTermuxMenu(pos);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _isSelecting = false;
  }

  void _onLongPressTriggered() {
    final startLocal = _touchStartLocal;
    final terminal = _terminal;
    final renderTerminal = _renderTerminal;

    if (startLocal == null || terminal == null || renderTerminal == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    final cellOffset = renderTerminal.getCellOffset(startLocal);
    final wordBoundary = terminal.buffer.getWordBoundary(cellOffset);

    final wordText = wordBoundary != null
        ? terminal.buffer.getText(wordBoundary, true)
        : '';

    if (wordText.trim().isNotEmpty && wordBoundary != null) {
      _selectionIsEmptiness = false;
      _controller.setSelection(
        terminal.buffer.createAnchorFromOffset(wordBoundary.begin),
        terminal.buffer.createAnchorFromOffset(wordBoundary.end),
      );
    } else {
      _selectionIsEmptiness = true;
      _controller.setSelection(
        terminal.buffer.createAnchor(cellOffset.x, cellOffset.y),
        terminal.buffer.createAnchor(cellOffset.x + 1, cellOffset.y),
      );
    }

    _isSelecting = true;

    setState(() {
      _termuxMenuPosition = null;
    });
  }

  Map<ShortcutActivator, Intent> _shortcuts(bool ctrlV) {
    final map = <ShortcutActivator, Intent>{
      for (final entry in defaultTerminalShortcuts.entries)
        if (entry.value is! PasteTextIntent) entry.key: entry.value,
      const SingleActivator(
        LogicalKeyboardKey.keyV,
        control: true,
        shift: true,
      ): const _PasteIntent(),
      const SingleActivator(LogicalKeyboardKey.insert, shift: true):
          const _PasteIntent(),
    };

    if (ctrlV) {
      map[const SingleActivator(LogicalKeyboardKey.keyV, control: true)] =
          const _PasteIntent();
    }

    return map;
  }

  void _reconnect() {
    setState(() {
      _showLogManually = false;
    });

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

    if (session == null) {
      return const SizedBox.shrink();
    }

    final showFailure =
        _showLogManually ||
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
          _PasteIntent: CallbackAction<_PasteIntent>(
            onInvoke: (_) {
              _paste();
              return null;
            },
          ),
        },
        child: TerminalView(
          session.terminal,
          key: _terminalViewKey,
          scrollController: _scrollController,
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
          keyboardType: TextInputType.multiline,
          onSecondaryTapDown: (details, _) {
            _onSecondaryClick(details.globalPosition, details.localPosition);
          },
        ),
      ),
    );

    final isCompact =
        MediaQuery.sizeOf(context).width < 650 || DesktopEnv.isMobile;

    final terminalArea = ColoredBox(
      color: terminalBackgroundFor(scheme, ext),
      child: Stack(
        key: _terminalStackKey,
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
              onErase: _eraseCurrentSelectionOrLine,
              onShare: _share,
              onReset: _reset,
              onClear: _clear,
              onLog: () {
                _dismissTermuxMenu();

                setState(() {
                  _showLogManually = true;
                });
              },
              onReconnect: () {
                _dismissTermuxMenu();
                _reconnect();
              },
              onDismiss: _dismissTermuxMenu,
            ),
          if (_controller.selection != null &&
              !_controller.selection!.isCollapsed) ...[
            _selectionHandle(start: true),
            _selectionHandle(start: false),
          ],
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
                    SftpPane(
                      tab: widget.tab,
                      active: widget.active && paneOpen,
                    ),
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
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              final max =
                                  MediaQuery.sizeOf(context).width * 0.7;

                              _paneWidth = (_paneWidth - details.delta.dx)
                                  .clamp(260, max < 260 ? 260 : max)
                                  .toDouble();
                            });
                          },
                          child: Container(
                            width: 5,
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
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
          TerminalAccessoryBar(session: session, focusNode: _focus),
        _StatusBar(
          tab: widget.tab,
          serverVersion: session.serverVersion,
          filesOpen: paneOpen,
          onToggleFiles: () {
            ref.read(sftpPaneProvider.notifier).toggle(widget.tab.id);
          },
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

    final isCompact =
        MediaQuery.sizeOf(context).width < 650 || DesktopEnv.isMobile;

    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final (status, color) = switch (tab.status) {
      SessionStatus.connecting => (
        strings.isRussian ? 'Подключение…' : 'Connecting…',
        scheme.tertiary,
      ),
      SessionStatus.ready => (
        strings.isRussian ? 'Подключено' : 'Connected',
        Colors.green.shade500,
      ),
      SessionStatus.lost => (
        strings.isRussian ? 'Нет соединения' : 'Connection lost',
        scheme.error,
      ),
      SessionStatus.closed => (
        strings.isRussian ? 'Сессия завершена' : 'Session closed',
        scheme.outline,
      ),
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
          if (!isCompact &&
              serverVersion != null &&
              tab.status == SessionStatus.ready) ...[
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                serverVersion!,
                overflow: TextOverflow.ellipsis,
                style: style?.copyWith(color: scheme.outline),
              ),
            ),
          ],
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: theme.textTheme.bodySmall,
              foregroundColor: filesOpen
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
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
                        ? (strings.isRussian
                              ? 'Файлы  Ctrl+Shift+E'
                              : 'Files  Ctrl+Shift+E')
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
