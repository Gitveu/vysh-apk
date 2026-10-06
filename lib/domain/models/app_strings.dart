import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'app_settings.dart';

/// Централизованная локализация приложения (русский и английский языки).
class AppStrings {
  const AppStrings({required this.isRu});

  final bool isRu;

  bool get isRussian => isRu;

  static AppStrings of(
    BuildContext context, [
    AppLanguage language = AppLanguage.auto,
  ]) {
    if (language == AppLanguage.ru) return const AppStrings(isRu: true);
    if (language == AppLanguage.en) return const AppStrings(isRu: false);

    final loc =
        Localizations.maybeLocaleOf(context) ??
        (ui.PlatformDispatcher.instance.locales.isNotEmpty
            ? ui.PlatformDispatcher.instance.locales.first
            : ui.PlatformDispatcher.instance.locale);
    final code = loc.languageCode.toLowerCase();
    final ru =
        code.startsWith('ru') || code.startsWith('be') || code.startsWith('uk');
    return AppStrings(isRu: ru);
  }

  // Общие действия
  String get ok => isRu ? 'ОК' : 'OK';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get delete => isRu ? 'Удалить' : 'Delete';
  String get edit => isRu ? 'Изменить' : 'Edit';
  String get close => isRu ? 'Закрыть' : 'Close';
  String get copy => isRu ? 'Копировать' : 'Copy';
  String get paste => isRu ? 'Вставить' : 'Paste';
  String get cut => isRu ? 'Вырезать' : 'Cut';
  String get duplicate => isRu ? 'Дублировать' : 'Duplicate';
  String get reconnect => isRu ? 'Переподключить' : 'Reconnect';
  String get search => isRu ? 'Поиск' : 'Search';
  String get actions => isRu ? 'Действия' : 'Actions';
  String get retry => isRu ? 'Повторить попытку' : 'Retry';
  String get dismiss => isRu ? 'Скрыть' : 'Dismiss';
  String get more => isRu ? 'Ещё' : 'More';

  // Навигация и полоса вкладок
  String get home => isRu ? 'Главная' : 'Home';
  String get homeTooltip => isRu ? 'Главная (Alt+1)' : 'Home (Alt+1)';
  String get newTabTooltip => isRu ? 'Новая вкладка' : 'New tab';
  String get newTabDesktopTooltip =>
      isRu ? 'Новая вкладка (Ctrl+Shift+T)' : 'New tab (Ctrl+Shift+T)';
  String get settingsTooltip => isRu ? 'Настройки' : 'Settings';
  String get settingsDesktopTooltip =>
      isRu ? 'Настройки (Ctrl+,)' : 'Settings (Ctrl+,)';
  String get closeTab => isRu ? 'Закрыть вкладку' : 'Close tab';
  String get hosts => isRu ? 'Хосты' : 'Hosts';
  String get settings => isRu ? 'Настройки' : 'Settings';

  // Главная страница / список хостов
  String get searchHostsHintMobile =>
      isRu ? 'Поиск хостов...' : 'Search hosts...';
  String get searchHostsHintDesktop =>
      isRu ? 'Поиск или user@host:port' : 'Search or user@host:port';
  String get newHost => isRu ? 'Новый хост' : 'New host';
  String get quickConnectPrefix =>
      isRu ? 'Быстрое подключение: enter' : 'Quick connect: Enter';
  String get noHostsTitle => isRu ? 'Хостов пока нет' : 'No hosts yet';
  String get noHostsDesc => isRu
      ? 'Добавьте первый сервер кнопкой выше или введите user@host:port в строку поиска.'
      : 'Add your first server using the button above or enter user@host:port in the search bar.';
  String get noSearchResults => isRu ? 'Ничего не найдено' : 'Nothing found';
  String get deleteHostTitle => isRu ? 'Удалить хост?' : 'Delete host?';
  String deleteHostDesc(String title) => isRu
      ? '«$title» будет удалён из списка.'
      : '«$title» will be deleted from the list.';
  String get forgetPassword => isRu ? 'Забыть пароль' : 'Forget password';
  String get passwordForgotten =>
      isRu ? 'Пароль удалён из хранилища' : 'Password removed from storage';
  String get noGroup => isRu ? 'Без группы' : 'No group';

  // Редактор хоста
  String get editHostTitle => isRu ? 'Редактирование хоста' : 'Edit host';
  String get duplicateHostTitle =>
      isRu ? 'Дублирование хоста' : 'Duplicate host';
  String get newHostTitle => isRu ? 'Новый хост' : 'New host';
  String get labelField => isRu ? 'Название' : 'Label';
  String get labelHint =>
      isRu ? 'Например, Prod EU, Домашний NAS' : 'e.g., Prod EU, Home NAS';
  String get addressField => isRu ? 'Адрес сервера' : 'Server address';
  String get addressHint =>
      isRu ? 'IP-адрес или домен' : 'IP address or domain';
  String get portField => isRu ? 'Порт' : 'Port';
  String get userField => isRu ? 'Пользователь' : 'Username';
  String get groupField => isRu ? 'Группа (необязательно)' : 'Group (optional)';
  String get groupHint =>
      isRu ? 'Например, Продакшн, Домашние' : 'e.g., Production, Home';
  String get authMethod =>
      isRu ? 'Способ авторизации' : 'Authentication method';
  String get authPassword => isRu ? 'Пароль' : 'Password';
  String get authKey => isRu ? 'SSH-ключ' : 'SSH key';
  String get passwordField => isRu ? 'Пароль' : 'Password';
  String get passwordPlaceholderSaved =>
      isRu ? '••••••••  (сохранён)' : '••••••••  (saved)';
  String get rememberPasswordCheckbox =>
      isRu ? 'Сохранить пароль' : 'Remember password';
  String get rememberPasswordSub => isRu
      ? 'Пароль будет надёжно сохранён в системном хранилище ключей'
      : 'Password will be stored securely in the system keychain';
  String get privateKeyField =>
      isRu ? 'Путь к приватному ключу' : 'Private key path';
  String get selectKeyFile => isRu ? 'Выбрать файл' : 'Select file';
  String get cardColor => isRu ? 'Цвет карточки' : 'Card color';
  String get keepAliveField =>
      isRu ? 'SSH KeepAlive (интервал)' : 'SSH KeepAlive (interval)';
  String get keepAliveDefault =>
      isRu ? 'По умолчанию из настроек' : 'Default from settings';
  String get keepAliveOff => isRu ? 'Отключён' : 'Disabled';
  String keepAliveSecondsVal(int s) => isRu ? '$s сек' : '$s sec';
  String get connectImmediately =>
      isRu ? 'Подключиться сразу' : 'Connect immediately';
  String get requiredField => isRu ? 'Обязательное поле' : 'Required field';
  String get invalidPort => isRu ? 'Некорректный порт' : 'Invalid port';

  // Настройки
  String get appearanceSection => isRu ? 'Внешний вид' : 'Appearance';
  String get themeTitle => isRu ? 'Тема' : 'Theme';
  String get themeSystem => isRu ? 'Системная' : 'System';
  String get themeLight => isRu ? 'Светлая' : 'Light';
  String get themeDark => isRu ? 'Тёмная' : 'Dark';
  String get colorSourceTitle => isRu ? 'Цвета' : 'Colors';
  String get colorSourcePreset => isRu ? 'Свои' : 'Custom';
  String get colorSourceSystem => isRu ? 'Системный акцент' : 'System accent';
  String get colorSourceSystemWin => isRu ? 'Акцент Windows' : 'Windows accent';
  String get colorSourceSystemSys => isRu ? 'Акцент системы' : 'System accent';
  String get colorSourceDots => isRu ? 'Из дотов' : 'From dots';
  String get compactUi => isRu ? 'Компактный интерфейс' : 'Compact interface';
  String get titleBarTitle => isRu ? 'Заголовок окна' : 'Window title bar';
  String get titleBarCustom => isRu ? 'Свой с вкладками' : 'Custom with tabs';
  String get titleBarSystem => isRu ? 'Системный' : 'System';
  String get windowSection => isRu ? 'Окно' : 'Window';
  String get hostsSection => isRu ? 'Хосты' : 'Hosts';
  String get pingHostsTitle =>
      isRu ? 'Проверять доступность хостов' : 'Check host reachability';
  String get pingHostsDesc => isRu
      ? 'На главной — пинг порта SSH раз в 30 секунд. Выключите, чтобы не нагружать удалённые серверы.'
      : 'Pings the SSH port every 30 seconds on the home screen. Turn off to avoid frequent network queries.';
  String get keepAliveGlobalTitle =>
      isRu ? 'SSH KeepAlive (поддержание связи)' : 'SSH KeepAlive (heartbeat)';
  String get keepAliveRecom =>
      isRu ? '60 сек (1 мин) — рекомендовано' : '60 sec (1 min) — recommended';
  String get terminalSection => isRu ? 'Терминал' : 'Terminal';
  String get fontSizeTitle => isRu ? 'Размер шрифта' : 'Font size';
  String get rememberTerminalFontSizeTitle =>
      isRu ? 'Запоминать размер шрифта' : 'Remember terminal font size';
  String get rememberTerminalFontSizeDesc => isRu
      ? 'Сохранять размер между запусками приложения'
      : 'Keep the terminal font size between app launches';
  String get copyOnSelectTitle =>
      isRu ? 'Копировать при выделении' : 'Copy on select';
  String get copyOnSelectMobileDesc => isRu
      ? 'Автоматически копировать выделенный текст в буфер'
      : 'Automatically copy highlighted text to clipboard';
  String get copyOnSelectDesktopDesc => isRu
      ? 'Как в терминалах Linux. Вставка — Ctrl+Shift+V'
      : 'Linux terminal style. Paste with Ctrl+Shift+V';
  String get accessoryBarTitle => isRu
      ? 'Панель горячих клавиш (Ctrl, Esc, стрелки)'
      : 'Terminal accessory bar (Ctrl, Esc, arrows)';
  String get accessoryBarDesc => isRu
      ? 'Однострочная панель keyboard над клавиатурой на смартфонах.'
      : 'Single-row keyboard style toolbar above the mobile keyboard.';
  String get languageTitle => isRu ? 'Язык интерфейса' : 'Interface language';
  String get languageAuto =>
      isRu ? 'Авто (Android / система)' : 'Auto (System / OS)';
  String get languageRu => isRu ? 'Русский (Russian)' : 'Russian (Русский)';
  String get languageEn => isRu ? 'English (Английский)' : 'English';
  String get rightClickMobileTitle =>
      isRu ? 'Тап двумя пальцами' : 'Two-finger tap';
  String get rightClickDesktopTitle => isRu
      ? 'Правый клик и тап двумя пальцами'
      : 'Right click & two-finger tap';
  String get rightClickMenu => isRu ? 'Меню' : 'Menu';
  String get rightClickPaste => isRu ? 'Вставка' : 'Paste';
  String get rightClickSmart => isRu ? 'Копировать / вставить' : 'Copy / paste';
  String get rightClickHintMenu =>
      isRu ? 'Открывает контекстное меню.' : 'Opens context menu.';
  String get rightClickHintPaste => isRu
      ? 'Сразу вставляет текст из буфера обмена.'
      : 'Pastes clipboard content directly.';
  String get rightClickHintSmart => isRu
      ? 'Если есть выделение — копирует его; если нет — вставляет.'
      : 'If text is selected, copies it; otherwise pastes.';
  String get shiftRightClickNote => isRu
      ? 'Shift + правый клик всегда открывает меню.'
      : 'Shift + right click always opens the menu.';
  String get multilinePasteTitle => isRu
      ? 'Предупреждать при вставке нескольких строк'
      : 'Warn before multiline paste';
  String get multilinePasteDesc => isRu
      ? 'Защита от случайного выполнения команд при копировании скриптов'
      : 'Protection against accidental command execution when pasting scripts';
  String get copyOnSelectDesc => isRu
      ? 'Выделенный текст сразу попадает в буфер обмена'
      : 'Copy highlighted text immediately';
  String get rightClickTitle => isRu ? 'Правый клик' : 'Right click';
  String get confirmMultilinePasteTitle => isRu ? 'Предупреждать при многострочной вставке' : 'Confirm multiline paste';
  String get confirmMultilinePasteDesc => isRu ? 'Защита от случайного выполнения команд' : 'Protection from accidental command execution';
  String get aboutApp => isRu ? 'О программе' : 'About';
  String get appDescription => isRu
      ? 'Минималистичный и красивый SSH-клиент и менеджер подключений.'
      : 'Minimalist and elegant SSH client & connection manager.';

  // Сессия и статус-бар
  String get statusConnecting => isRu ? 'Подключение…' : 'Connecting…';
  String get statusConnected => isRu ? 'Подключено' : 'Connected';
  String get statusLost => isRu ? 'Нет соединения' : 'Connection lost';
  String get statusClosed => isRu ? 'Сессия завершена' : 'Session closed';
  String get files => isRu ? 'Файлы' : 'Files';
  String get console => isRu ? 'Консоль' : 'Console';
  String get filesShortcut =>
      isRu ? 'Файлы  Ctrl+Shift+E' : 'Files  Ctrl+Shift+E';
  String get reconnectShort => isRu ? 'Переподкл.' : 'Reconnect';
  String get sftpPaneTitle => isRu ? 'Файлы (SFTP)' : 'Files (SFTP)';

  // Ошибка подключения
  String get connectionFailed => isRu
      ? 'Не удалось подключиться к серверу'
      : 'Failed to connect to server';
  String get connectionLostTitle => isRu
      ? 'Соединение с сервером разорвано'
      : 'Connection to server was lost';
  String get sessionLog => isRu ? 'Журнал сессии' : 'Session log';

  // Контекстное меню keyboard (зажатие пальцем)
  String get selectLine => isRu ? 'Выбрать строку' : 'Select line';
  String get selectLineToast => isRu ? 'Строка выбрана' : 'Line selected';
  String get selectAll =>
      selectLine; // Выбирает строку целиком по запросу пользователя
  String get share => isRu ? 'Поделиться' : 'Share';
  String get reset => isRu ? 'Сброс (^C)' : 'Reset (^C)';
  String get clear => isRu ? 'Очистить (^L)' : 'Clear (^L)';
  String get sftp => isRu ? 'Файлы (SFTP)' : 'Files (SFTP)';
  String get log => isRu ? 'Журнал' : 'Log';
  String get deselect => isRu ? 'Снять выделение' : 'Deselect';
  String get terminal => isRu ? 'Терминал' : 'Terminal';
  String get emptyArea => isRu ? 'Пустая область' : 'Empty area';
  String get selectedText => isRu ? 'Текст' : 'Text';

  String charCount(int count) => isRu ? '$count симв.' : '$count chars';
  String copiedToast(int count) => isRu
      ? 'Скопировано в буфер ($count симв.)'
      : 'Copied to clipboard ($count chars)';
  String cutToast(int count) => isRu
      ? 'Вырезано в буфер ($count симв.)'
      : 'Cut to clipboard ($count chars)';
  String get pastedToast => isRu ? 'Вставлено' : 'Pasted';
  String get nothingToCopy =>
      isRu ? 'Нет текста для копирования' : 'No text to copy';
  String get resetToast =>
      isRu ? 'Отправлен сигнал прерывания (^C)' : 'Interrupt signal sent (^C)';
  String get clearToast => isRu ? 'Экран очищен' : 'Screen cleared';

  // Диалог вставки нескольких строк
  String multilineTitle(int count) =>
      isRu ? 'Вставить $count строк?' : 'Paste $count lines?';
  String get multilineDesc => isRu
      ? 'Каждая строка выполнится как отдельная команда.'
      : 'Each line will execute as a separate command.';
  String get pasteSingleLine => isRu ? 'Одной строкой' : 'Single line';
  String get pasteConfirm => isRu ? 'Вставить' : 'Paste';

  // Быстрые команды Ctrl (вспомогательная панель)
  String get ctrlQuickTitle =>
      isRu ? 'Быстрые команды Ctrl' : 'Ctrl Quick Commands';
  String get ctrlCSigint =>
      isRu ? 'Прервать процесс (SIGINT)' : 'Interrupt process (SIGINT)';
  String get ctrlDEof =>
      isRu ? 'Выход / Конец ввода (EOF)' : 'Exit / End of input (EOF)';
  String get ctrlZSuspend => isRu
      ? 'Приостановить в фон (SIGTSTP)'
      : 'Suspend to background (SIGTSTP)';
  String get ctrlLClear => isRu ? 'Очистить экран' : 'Clear screen';
  String get ctrlABeginning => isRu ? 'В начало строки' : 'Move to line start';
  String get ctrlEEnd => isRu ? 'В конец строки' : 'Move to line end';
  String get ctrlRSearch =>
      isRu ? 'Поиск по истории команд' : 'Reverse history search';

  // SFTP файловый менеджер
  String get pathField => isRu ? 'Путь' : 'Path';
  String get uploadFile => isRu ? 'Загрузить файл' : 'Upload file';
  String get createFolder => isRu ? 'Создать папку' : 'Create folder';
  String get folderNameHint => isRu ? 'Имя новой папки' : 'New folder name';
  String get emptyFolder => isRu ? 'В этой папке пусто' : 'Folder is empty';
  String get download => isRu ? 'Скачать' : 'Download';
  String get rename => isRu ? 'Переименовать' : 'Rename';
  String get newNameHint => isRu ? 'Новое имя' : 'New name';
  String get deleteFileConfirm =>
      isRu ? 'Удалить этот файл?' : 'Delete this file?';
  String get deleteFolderConfirm =>
      isRu ? 'Удалить эту папку?' : 'Delete this folder?';
  String get itemDeleted => isRu ? 'Удалено' : 'Deleted';
  String get downloadStarted => isRu ? 'Скачивание начато' : 'Download started';
  String get uploadStarted => isRu ? 'Загрузка начата' : 'Upload started';
}
