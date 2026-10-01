import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/domain/models/session_tab.dart';

// Файл с этим именем нужен, чтобы `flutter create .` не сгенерировал
// стандартный тест со счётчиком.
void main() {
  test('Главная вкладка активна по умолчанию', () {
    const state = TabsState();
    expect(state.isHome, isTrue);
    expect(state.activeTab, isNull);
  });
}
