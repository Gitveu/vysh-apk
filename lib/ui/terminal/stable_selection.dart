import 'package:flutter/widgets.dart';
import 'package:xterm2/xterm.dart';

class StableSelectionController extends TerminalController {}

class DragSelectionFix {
  DragSelectionFix({
    required this.controller,
    required this.viewKey,
    required this.scroll,
    required this.terminal,
  });

  final TerminalController controller;
  final GlobalKey<TerminalViewState> viewKey;
  final ScrollController scroll;
  final Terminal? Function() terminal;

  void onScroll() {}
  void dispose() {}
}
