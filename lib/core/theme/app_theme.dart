import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DeskAI 앱 컬러 팔레트 (Warm Minimal 컨셉)
class AppColors {
  AppColors._();

  // 액센트 (Muted Terracotta & Warm Beige)
  static const primary = Color(0xFFE2725B); // Muted Terracotta
  static const primaryLight = Color(0xFFECA090); // 연한 테라코타
  static const primaryDark = Color(0xFFC45A45); // 진한 테라코타

  static const secondary = Color(0xFFD4A373); // Warm Beige / Wood 톤
  static const secondaryLight = Color(0xFFE5C19D); // 아주 연한 베이지

  // 라이트 모드 (Off-White & Soft Sand 중심)
  static const lightBg = Color(0xFFFAF9F6); // Off-White
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF2C2A29); // 진한 웜 그레이/블랙
  static const lightTextSecondary = Color(0xFF7A7571); // 중간 웜 그레이
  static const lightTextTertiary = Color(0xFFB5AFAB); // 연한 웜 그레이
  static const lightDivider = Color(0xFFEAE6E2); // 부드러운 경계선
  static const lightCardBorder = Color(0xFFEAE6E2);

  // 다크 모드 (어두운 브라운/다크 그레이 톤으로 아늑함 유지)
  static const darkBg = Color(0xFF1C1A19);
  static const darkSurface = Color(0xFF252221);
  static const darkCard = Color(0xFF2A2625);
  static const darkTextPrimary = Color(0xFFEBE6E2); // 연한 웜 그레이
  static const darkTextSecondary = Color(0xFFAFAAA6); // 중간 웜 그레이
  static const darkTextTertiary = Color(0xFF75706C); // 진한 웜 그레이
  static const darkDivider = Color(0xFF3B3533);
  static const darkCardBorder = Color(0xFF3B3533);

  // 그라디언트
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const subtleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF9F5), Color(0xFFFFF2E8)], // 아주 따뜻하게 변경
  );

  // 기능별 컬러 (웜톤 계열로 약간의 채도를 낮춰 안정감 있게 조정)
  static const featureCleanup = Color(0xFFE2725B); // 테라코타
  static const featureFitting = Color(0xFF7B8C7A); // 차분한 그린 (식물 느낌)
  static const featureShopping = Color(0xFFD4A373); // 웜 베이지
}

/// DeskAI 앱 테마
class AppTheme {
  AppTheme._();

  // ──────────── 라이트 테마 ────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        error: Color(0xFFD32F2F),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F1ED), // 입력창은 배경보다 아주 약간 더 진한 웜 그레이
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.lightTextTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16, // 약간 더 넓게
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
      ),
    );
  }

  // ──────────── 다크 테마 ────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: Color(0xFFE57373),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight, // 다크모드에서는 약간 더 밝게
          side: const BorderSide(color: AppColors.darkCardBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final primaryColor = isLight
        ? AppColors.lightTextPrimary
        : AppColors.darkTextPrimary;
    final secondaryColor = isLight
        ? AppColors.lightTextSecondary
        : AppColors.darkTextSecondary;
    final tertiaryColor = isLight
        ? AppColors.lightTextTertiary
        : AppColors.darkTextTertiary;

    // 감성적이고 모던한 느낌을 위해 Noto Sans 폰트 사용 (한글/영문 모두 깔끔, 기존 유지)
    return GoogleFonts.notoSansTextTheme(
      TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32, // 약간 더 큼직하게
          fontWeight: FontWeight.w800,
          color: primaryColor,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: primaryColor,
          height: 1.3,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryColor,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryColor,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          letterSpacing: -0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: secondaryColor,
          height: 1.6, // 줄간격을 넓혀 읽기 편하게
        ),
        bodyMedium: TextStyle(
          fontSize: 15, // 약간 큼직하게 해서 여유 제공
          fontWeight: FontWeight.w400,
          color: secondaryColor,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tertiaryColor,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// 테마 확장 헬퍼 - context에서 편리하게 커스텀 색상 가져오기
extension ThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get bgColor => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textTertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  Color get dividerColor =>
      isDark ? AppColors.darkDivider : AppColors.lightDivider;
  Color get cardBorder =>
      isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
}
