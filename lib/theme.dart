import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';

class AppColors {
  // --- Stellarium Palette ---
  static const Color deepBlack = Color(0xFF000000);
  static const Color stellariumPurple = Color(0xFF1A0B2E);
  static const Color deepForest = Color(0xFF001A00);

  static const Color textPink = Color(0xFFD18BFF);
  static const Color textCyan = Color(0xFF00E5FF);
  static const Color gold = Color(0xFFFFD700);
  static const Color electricPurple = Color(0xFF7C3AED);

  // --- Aliases ---
  static const Color neonBlue = textCyan;
  static const String fontFamily = 'Frutiger'; // Custom Font Family

  // --- Main Background Gradient ---
  static const LinearGradient stellariumGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepBlack, stellariumPurple, deepForest],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient oceanGradient = stellariumGradient;

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFDB931), Color(0xFFFFD700), Color(0xFFFDB931)],
  );
}

class AppFontSizes {
  static const double xs = 10.0;
  static const double sm = 12.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double display = 32.0;
}

// --- Premium Typography Styles ---
class AppTypography {
  static const String fontFamily = 'Frutiger';

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppFontSizes.xxl,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  static const TextStyle medium = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppFontSizes.lg,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: AppFontSizes.sm,
    fontWeight: FontWeight.normal,
    color: Colors.white70,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get titleStyle => title;
  static TextStyle get mediumStyle => medium;
  static TextStyle get smallStyle => small;

  static TextTheme get textTheme => TextTheme(
    displayLarge: title.copyWith(fontSize: 32),
    displayMedium: title,
    titleLarge: title,
    bodyLarge: medium,
    bodyMedium: medium,
    bodySmall: small,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.electricPurple,
      scaffoldBackgroundColor: AppColors.deepBlack,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricPurple,
        secondary: AppColors.textCyan,
        surface: AppColors.stellariumPurple,
      ),
    );
  }
}

class WaterGlass extends StatelessWidget {
  final Widget child;
  final double height;
  final double? width;
  final double borderRadius;
  final double blur;
  final double border;
  final Color? borderColor;

  const WaterGlass({
    super.key,
    required this.child,
    this.height = 100,
    this.width,
    this.borderRadius = 20,
    this.blur = 15,
    this.border = 1.5,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to get available constraints instead of MediaQuery
    // This prevents geometry assertion errors in constrained contexts like ListView
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        return GlassmorphicContainer(
          width:
              width ??
              (availableWidth == double.infinity
                  ? MediaQuery.of(context).size.width
                  : availableWidth),
          height: height,
          borderRadius: borderRadius,
          blur: blur,
          alignment: Alignment.center,
          border: border,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (borderColor ?? Colors.white).withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ),
          child: child,
        );
      },
    );
  }
}
