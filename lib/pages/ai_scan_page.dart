import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class AIScanView extends StatefulWidget {
  const AIScanView({super.key});

  @override
  State<AIScanView> createState() => _AIScanViewState();
}

class _AIScanViewState extends State<AIScanView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  void _startScan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning... AI analysis coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'AI Camera Scanner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Point your camera at an item to identify and match it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2559),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const _ScanCorner(alignment: Alignment.topLeft),
                        const _ScanCorner(alignment: Alignment.topRight),
                        const _ScanCorner(alignment: Alignment.bottomLeft),
                        const _ScanCorner(alignment: Alignment.bottomRight),
                        const Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white24,
                            size: 56,
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _scan,
                          builder: (context, child) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final top =
                                    _scan.value * (constraints.maxHeight - 48) +
                                    24;
                                return Positioned(
                                  top: top,
                                  left: 20,
                                  right: 20,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Start AI Scan',
                  icon: Icons.center_focus_strong_rounded,
                  onPressed: _startScan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.primaryLight, width: 3);
    Border? border;
    BorderRadius? radius;
    switch (alignment) {
      case Alignment.topLeft:
        border = const Border(top: side, left: side);
        radius = const BorderRadius.only(topLeft: Radius.circular(18));
      case Alignment.topRight:
        border = const Border(top: side, right: side);
        radius = const BorderRadius.only(topRight: Radius.circular(18));
      case Alignment.bottomLeft:
        border = const Border(bottom: side, left: side);
        radius = const BorderRadius.only(bottomLeft: Radius.circular(18));
      case Alignment.bottomRight:
        border = const Border(bottom: side, right: side);
        radius = const BorderRadius.only(bottomRight: Radius.circular(18));
      default:
        break;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(border: border, borderRadius: radius),
        ),
      ),
    );
  }
}
