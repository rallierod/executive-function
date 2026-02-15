import 'package:flutter/material.dart';

import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_shell.dart';

class ExecutiveFunctionApp extends StatelessWidget {
  const ExecutiveFunctionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Executive Function',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
