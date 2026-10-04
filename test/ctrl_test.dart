import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/domain/services/terminal_session.dart';

void main() {
  group('TerminalSession Ctrl combinations', () {
    test('mapToCtrlChar maps all English letters to uppercase', () {
      expect(TerminalSession.mapToCtrlChar('c'), 'C');
      expect(TerminalSession.mapToCtrlChar('C'), 'C');
      expect(TerminalSession.mapToCtrlChar('a'), 'A');
      expect(TerminalSession.mapToCtrlChar('z'), 'Z');
      expect(TerminalSession.mapToCtrlChar('d'), 'D');
      expect(TerminalSession.mapToCtrlChar('u'), 'U');
      expect(TerminalSession.mapToCtrlChar('l'), 'L');
    });

    test('mapToCtrlChar maps Cyrillic letters to QWERTY Latin', () {
      expect(TerminalSession.mapToCtrlChar('с'), 'C'); // Cyrillic s -> C
      expect(TerminalSession.mapToCtrlChar('С'), 'C');
      expect(TerminalSession.mapToCtrlChar('в'), 'D'); // Cyrillic v -> D
      expect(TerminalSession.mapToCtrlChar('я'), 'Z'); // Cyrillic ya -> Z
      expect(TerminalSession.mapToCtrlChar('г'), 'U'); // Cyrillic g -> U
      expect(TerminalSession.mapToCtrlChar('д'), 'L'); // Cyrillic d -> L
      expect(TerminalSession.mapToCtrlChar('ф'), 'A'); // Cyrillic f -> A
    });

    test('mapToCtrlChar ignores numbers or invalid symbols', () {
      expect(TerminalSession.mapToCtrlChar('1'), isNull);
      expect(TerminalSession.mapToCtrlChar(''), isNull);
    });
  });
}
