import 'package:flutter/services.dart';

class Modifiers {
  Modifiers._();
  static final instance = Modifiers._();

  bool get shift => HardwareKeyboard.instance.isShiftPressed;
  bool get ctrl => HardwareKeyboard.instance.isControlPressed;
  bool get alt => HardwareKeyboard.instance.isAltPressed;
  bool get meta => HardwareKeyboard.instance.isMetaPressed;
}
