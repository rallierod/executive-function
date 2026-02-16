import 'package:flutter/material.dart';

import '../theme/app_theme_ext.dart';

class ScreenShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ScreenShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      decoration: BoxDecoration(gradient: t.backgroundGradient),
      child: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
