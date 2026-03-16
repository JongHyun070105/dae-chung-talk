import 'package:flutter/material.dart';

/// 그라디언트 배경 위젯 (미사용 - 호환성 유지용)
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
