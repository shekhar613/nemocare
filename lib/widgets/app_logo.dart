import 'package:flutter/material.dart';

/// Canonical Nemo Care brand mark.
class AppLogo {
  static const assetPath = 'assets/images/nemo-logo.png';

  AppLogo._();
}

/// Renders the Nemo Care logo with consistent rounding and fit.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final double size;
  final double? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        AppLogo.assetPath,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Nemo Care',
      ),
    );
  }
}
