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

    // Цвета дефолтной иконки (оригинальная пастельная лаванда)
    const defaultBg = Color(0xFFCAB8E8);
    const defaultGlyph = Color(0xFF463553);

    // Цвета Monet иконки (динамически из системы Android)
    final monetBg = _monetColors?.background ?? const Color(0xFF18181A);
    final monetGlyph = _monetColors?.accent ?? const Color(0xFFA8DAB5);

    final isMonet = _selectedId == 'monet';
    final currentBg = isMonet ? monetBg : defaultBg;
    final currentGlyph = isMonet ? monetGlyph : defaultGlyph;
    final currentTitle = isMonet ? 'Monet' : 'Основная';

    // Цвет кнопки «Оставить такую» как в AyuGram
    final buttonColor = isMonet ? monetGlyph : defaultBg;
    final buttonTextColor = isMonet ? const Color(0xFF1B3722) : defaultGlyph;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор иконки'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Большое превью выбранной иконки в центре
            _IconGlyph(
              size: 96,
              bgColor: currentBg,
              glyphColor: currentGlyph,
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
                    bg: defaultBg,
                    glyph: defaultGlyph,
                    selected: _selectedId == 'default',
                  ),
                  _iconCard(
                    id: 'monet',
                    title: 'Monet',
                    bg: monetBg,
                    glyph: monetGlyph,
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
    required Color bg,
    required Color glyph,
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
                  bgColor: bg,
                  glyphColor: glyph,
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
    required this.bgColor,
    required this.glyphColor,
  });

  final double size;
  final Color bgColor;
  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.54, size * 0.54),
          painter: _LogoPainter(color: glyphColor),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Левый шеврон '>' (глаз)
    final leftEye = Path()
      ..moveTo(size.width * 0.14, size.height * 0.33)
      ..lineTo(size.width * 0.38, size.height * 0.49)
      ..lineTo(size.width * 0.14, size.height * 0.65);
    canvas.drawPath(leftEye, stroke);

    // Правый шеврон '<' (глаз)
    final rightEye = Path()
      ..moveTo(size.width * 0.86, size.height * 0.33)
      ..lineTo(size.width * 0.62, size.height * 0.49)
      ..lineTo(size.width * 0.86, size.height * 0.65);
    canvas.drawPath(rightEye, stroke);

    // Ротик '_'
    canvas.drawLine(
      Offset(size.width * 0.41, size.height * 0.70),
      Offset(size.width * 0.59, size.height * 0.70),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.color != color;
}
