import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/settings_controller.dart';
import '../../infra/platform/app_icon_manager.dart';

class IconOption {
  const IconOption({
    required this.id,
    required this.title,
    required this.backgroundColor,
    required this.glyphColor,
    this.isMonet = false,
  });

  final String id;
  final String title;
  final Color backgroundColor;
  final Color glyphColor;
  final bool isMonet;
}

class AppIconPickerPage extends ConsumerStatefulWidget {
  const AppIconPickerPage({super.key});

  @override
  ConsumerState<AppIconPickerPage> createState() => _AppIconPickerPageState();
}

class _AppIconPickerPageState extends ConsumerState<AppIconPickerPage> {
  late String _selectedId;

  static const _options = [
    IconOption(
      id: 'default',
      title: 'Основная',
      backgroundColor: Color(0xFF6750A4),
      glyphColor: Colors.white,
    ),
    IconOption(
      id: 'monet',
      title: 'Monet',
      backgroundColor: Color(0xFF2B2930),
      glyphColor: Color(0xFFD0BCFF),
      isMonet: true,
    ),
    IconOption(
      id: 'dark',
      title: 'OLED / Тёмная',
      backgroundColor: Color(0xFF141416),
      glyphColor: Colors.white,
    ),
    IconOption(
      id: 'matrix',
      title: 'Терминал',
      backgroundColor: Color(0xFF0A190E),
      glyphColor: Color(0xFF00FF66),
    ),
    IconOption(
      id: 'discord',
      title: 'Discord',
      backgroundColor: Color(0xFF5865F2),
      glyphColor: Colors.white,
    ),
    IconOption(
      id: 'spotify',
      title: 'Spotify',
      backgroundColor: Color(0xFF191414),
      glyphColor: Color(0xFF1ED760),
    ),
    IconOption(
      id: 'nothing',
      title: 'Nothing',
      backgroundColor: Colors.white,
      glyphColor: Color(0xFFD71921),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedId = ref.read(settingsProvider).appIcon;
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
    final scheme = theme.colorScheme;

    final currentOption = _options.firstWhere(
      (o) => o.id == _selectedId,
      orElse: () => _options.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор иконки'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Большое превью выбранной иконки
            _IconGlyph(
              size: 88,
              bgColor: currentOption.isMonet ? scheme.surfaceContainerHighest : currentOption.backgroundColor,
              glyphColor: currentOption.isMonet ? scheme.primary : currentOption.glyphColor,
            ),
            const SizedBox(height: 14),
            Text(
              currentOption.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            // Сетка иконок
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.76,
                ),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = option.id == _selectedId;

                  final bg = option.isMonet ? scheme.surfaceContainerHighest : option.backgroundColor;
                  final fg = option.isMonet ? scheme.primary : option.glyphColor;

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedId = option.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.surfaceContainerHighest.withValues(alpha: 0.8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: scheme.primary.withValues(alpha: 0.5), width: 1.5)
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _IconGlyph(
                                size: 52,
                                bgColor: bg,
                                glyphColor: fg,
                              ),
                              if (isSelected)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 13,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Кнопка внизу экрана
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _apply,
                  child: const Text(
                    'Оставить такую',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
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
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.52, size * 0.52),
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
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Chevron '>'
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.2)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.15, size.height * 0.8);
    canvas.drawPath(path, stroke);

    // Cursor line '_'
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.8),
      Offset(size.width * 0.95, size.height * 0.8),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.color != color;
}
