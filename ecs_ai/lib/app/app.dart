import 'package:flutter/material.dart';

import 'package:ecs_ai/app/theme/app_theme.dart';
import 'package:ecs_ai/features/canvas/screens/workspace_screen.dart';

/// root application widget
class EcsApp extends StatelessWidget {
  const EcsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECS AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WorkspaceScreen(),
    );
  }
}
