import 'package:flutter/material.dart';

class AppBrand {
  const AppBrand._();

  static const name = 'MerkaERP';
  static const tagline = 'Plataforma ERP empresarial';
  static const description =
      'Operacion, finanzas, contabilidad y control en un solo sistema.';

  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF2563EB);
  static const accent = Color(0xFF1D4ED8);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF4B5563);
  static const surface = Color(0xFFF3F4F6);
  static const darkSurface = Color(0xFF374151);
  static const darkBackground = Color(0xFF1F2937);
}

class MerkaLogo extends StatelessWidget {
  const MerkaLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppBrand.primary,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: AppBrand.secondary.withValues(alpha: 0.22),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: const BoxDecoration(
                color: AppBrand.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MerkaBrandHeader extends StatelessWidget {
  const MerkaBrandHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.headlineSmall;
    return Row(
      children: [
        MerkaLogo(size: compact ? 42 : 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppBrand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppBrand.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppBrand.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
