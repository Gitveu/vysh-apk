import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/host.dart';
import '../../domain/services/hosts_controller.dart';
import '../../domain/services/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Открыть боковую панель создания/редактирования хоста.
Future<void> showHostEditor(BuildContext context, {Host? host, bool duplicate = false}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: _HostEditorSheet(host: host, duplicate: duplicate),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _HostEditorSheet extends ConsumerStatefulWidget {
  const _HostEditorSheet({this.host, this.duplicate = false});

  final Host? host;
  final bool duplicate;

  @override
  ConsumerState<_HostEditorSheet> createState() => _HostEditorSheetState();
}

class _HostEditorSheetState extends ConsumerState<_HostEditorSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _address;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _keyPath;
  late final TextEditingController _group;
  late AuthMethod _auth;
  late int _color;

  bool get _isEdit => widget.host != null && !widget.duplicate;

  @override
  void initState() {
    super.initState();
    final h = widget.host;
    _label = TextEditingController(
        text: h == null ? '' : (widget.duplicate ? '${h.title} (копия)' : h.label));
    _address = TextEditingController(text: h?.address ?? '');
    _port = TextEditingController(text: '${h?.port ?? 22}');
    _user = TextEditingController(text: h?.username ?? 'root');
    _keyPath = TextEditingController(text: h?.keyPath ?? '');
    _group = TextEditingController(text: h?.group ?? '');
    _auth = h?.auth ?? AuthMethod.password;
    _color = h?.color ?? hostColors.first;
  }

  @override
  void dispose() {
    for (final c in [_label, _address, _port, _user, _keyPath, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  Host? _buildHost() {
    if (!(_form.currentState?.validate() ?? false)) return null;
    final key = _keyPath.text.trim();
    return Host(
      id: _isEdit ? widget.host!.id : newId(),
      label: _label.text.trim(),
      address: _address.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _user.text.trim(),
      auth: _auth,
      keyPath: _auth == AuthMethod.key && key.isNotEmpty ? key : null,
      group: _group.text.trim(),
      color: _color,
      lastConnectedAt: _isEdit ? widget.host!.lastConnectedAt : null,
    );
  }

  void _save({bool connect = false}) {
    final host = _buildHost();
    if (host == null) return;
    ref.read(hostsProvider.notifier).upsert(host);
    Navigator.of(context).pop();
    if (connect) ref.read(tabsProvider.notifier).openHost(host);
  }

  InputDecoration _dec(String label, {String? hint, Widget? icon, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: icon,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups = ref.watch(hostGroupsProvider);
    final width = MediaQuery.sizeOf(context).width;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _save(),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Material(
        color: scheme.surfaceContainerLow,
        elevation: 2,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width < 520 ? width : 440,
          height: double.infinity,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_isEdit ? 'Изменить хост' : 'Новый хост',
                            style: theme.textTheme.titleLarge),
                      ),
                      IconButton(
                        tooltip: 'Закрыть (Esc)',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      TextFormField(
                        controller: _address,
                        autofocus: !_isEdit,
                        decoration: _dec('Адрес', hint: '192.168.1.10 или example.com',
                            icon: const Icon(Icons.public)),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Укажите адрес' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _user,
                              decoration: _dec('Пользователь', icon: const Icon(Icons.person_outline)),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Укажите логин' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _port,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _dec('Порт'),
                              validator: (v) {
                                final p = int.tryParse(v ?? '');
                                return (p == null || p < 1 || p > 65535) ? '1–65535' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _label,
                        decoration: _dec('Название', hint: 'Необязательно',
                            icon: const Icon(Icons.label_outline)),
                      ),
                      const SizedBox(height: 20),
                      Text('Аутентификация', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      SegmentedButton<AuthMethod>(
                        segments: const [
                          ButtonSegment(value: AuthMethod.password, label: Text('Пароль'),
                              icon: Icon(Icons.password)),
                          ButtonSegment(value: AuthMethod.key, label: Text('Ключ'),
                              icon: Icon(Icons.key)),
                          ButtonSegment(value: AuthMethod.agent, label: Text('Авто'),
                              icon: Icon(Icons.auto_awesome)),
                        ],
                        selected: {_auth},
                        onSelectionChanged: (s) => setState(() => _auth = s.first),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: switch (_auth) {
                          AuthMethod.key => TextFormField(
                              controller: _keyPath,
                              decoration: _dec('Путь к приватному ключу',
                                  hint: '~/.ssh/id_ed25519',
                                  icon: const Icon(Icons.vpn_key_outlined)),
                            ),
                          AuthMethod.password => _Note(
                              'Пароль спросим при подключении — его можно сохранить '
                              'в системном хранилище (Credential Manager / Secret Service).'),
                          AuthMethod.agent => _Note(
                              'Попробуем стандартные ключи из ~/.ssh: id_ed25519, id_ecdsa, id_rsa '
                              '(без парольной фразы). ssh-agent и Pageant — позже.'),
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _group,
                        decoration: _dec('Группа', hint: 'Например: prod, дом, клиенты',
                            icon: const Icon(Icons.folder_outlined)),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (groups.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final g in groups)
                              ChoiceChip(
                                label: Text(g),
                                selected: _group.text.trim() == g,
                                onSelected: (on) => setState(() => _group.text = on ? g : ''),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('Цвет метки', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final c in hostColors)
                            _ColorDot(
                              color: Color(c),
                              selected: c == _color,
                              onTap: () => setState(() => _color = c),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
                  child: Row(
                    children: [
                      if (_isEdit)
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: scheme.error),
                          onPressed: () {
                            ref.read(hostsProvider.notifier).remove(widget.host!.id);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Удалить'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _save(connect: true),
                        child: const Text('Сохранить и подключиться'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}
