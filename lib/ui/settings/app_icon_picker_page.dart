import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/settings_controller.dart';
import '../../infra/platform/app_icon_manager.dart';

class AppIconPickerPage extends ConsumerStatefulWidget {
  const AppIconPickerPage({super.key});

  @override
  ConsumerState<AppIconPickerPage> createState() => _AppIconPickerPageState();
}

class _AppIconPickerPageState extends ConsumerState<AppIconPickerPage> {
  late String _selectedId;
  MonetColors? _monetColors;

  @override
  void initState() {
    super.initState();
    _selectedId = ref.read(settingsProvider).appIcon;
    _loadMonetColors();
  }

  Future<void> _loadMonetColors() async {
    final colors = await AppIconManager.getMonetColors();
    if (mounted && colors != null) {
      setState(() => _monetColors = colors);
    }
  }

  void _apply() async {
    HapticFeedback.mediumImpact();
    ref.read(settingsProvider.notifier).setAppIcon(_selectedId);
    await AppIconManager.setIcon(_selectedId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Иконка приложения обновлена'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Цвета Monet иконки (динамически из системы Android)
    final monetBg = _monetColors?.background ?? const Color(0xFF18181A);
    final monetGlyph = _monetColors?.accent ?? const Color(0xFFA8DAB5);

    final isMonet = _selectedId == 'monet';
    final currentTitle = isMonet ? 'Monet' : 'Основная';

    // Цвет кнопки «Оставить такую»
    const defaultBtnBg = Color(0xFFCAB8E8);
    const defaultBtnFg = Color(0xFF463553);
    final buttonColor = isMonet ? monetGlyph : defaultBtnBg;
    final buttonTextColor = isMonet ? const Color(0xFF1B3722) : defaultBtnFg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор иконки'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Большое превью выбранной иконки (полноразмерное, один в один как на рабочем столе)
            _IconGlyph(
              size: 96,
              isMonet: isMonet,
              monetBg: monetBg,
              monetGlyph: monetGlyph,
            ),
            const SizedBox(height: 16),
            Text(
              currentTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 36),
            // Выбор между двумя иконками: Основная и Monet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconCard(
                    id: 'default',
                    title: 'Основная',
                    isMonet: false,
                    selected: _selectedId == 'default',
                  ),
                  _iconCard(
                    id: 'monet',
                    title: 'Monet',
                    isMonet: true,
                    monetBg: monetBg,
                    monetGlyph: monetGlyph,
                    selected: _selectedId == 'monet',
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Кнопка внизу экрана «Оставить такую»
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _apply,
                  child: const Text(
                    'Оставить такую',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconCard({
    required String id,
    required String title,
    required bool isMonet,
    Color? monetBg,
    Color? monetGlyph,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedId = id);
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: scheme.primary.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _IconGlyph(
                  size: 60,
                  isMonet: isMonet,
                  monetBg: monetBg,
                  monetGlyph: monetGlyph,
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _selectedId == 'monet' && _monetColors != null
                            ? _monetColors!.accentPrimary
                            : scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: _selectedId == 'monet' && _monetColors != null
                            ? Colors.black
                            : scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconGlyph extends StatelessWidget {
  const _IconGlyph({
    required this.size,
    required this.isMonet,
    this.monetBg,
    this.monetGlyph,
  });

  final double size;
  final bool isMonet;
  final Color? monetBg;
  final Color? monetGlyph;

  @override
  Widget build(BuildContext context) {
    Widget iconImage;

    if (!isMonet) {
      // Истинная оригинальная иконка (один в один со скриншота номер один)
      iconImage = Image.asset(
        'assets/icon/ic_launcher.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else {
      final bg = monetBg ?? const Color(0xFF18181A);
      final fg = monetGlyph ?? const Color(0xFFA8DAB5);
      // Маска оригинальной иконки (сохраняет точный крупный размер >_< и пропорции)
      iconImage = SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/icon/ic_bg_mask.png',
              color: bg,
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            Image.asset(
              'assets/icon/ic_fg_mask.png',
              color: fg,
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: iconImage,
    );
  }
}
