import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class WorkspaceDrawer extends StatelessWidget {
  const WorkspaceDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.surfaceVariant),
            child: Text(
              'ECS AI',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Open Project',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context); // close drawer
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.save_outlined,
              color: AppColors.textPrimary,
            ),
            title: const Text(
              'Save Project',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context); // close drawer
            },
          ),
        ],
      ),
    );
  }
}
