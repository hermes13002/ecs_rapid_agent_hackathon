import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/services/auth_service.dart';
import 'package:ecs_ai/features/auth/widgets/auth_dialog.dart';

class WorkspaceToolbar extends StatelessWidget {
  final VoidCallback onLogoutSuccess;

  const WorkspaceToolbar({super.key, required this.onLogoutSuccess});

  Widget _buildMenuButton(String title) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      child: Text(title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: AppConstants.toolbarHeight,
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  splashRadius: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ECS-AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 24),
              _buildMenuButton('File'),
              _buildMenuButton('Edit'),
              _buildMenuButton('Simulate'),
              _buildMenuButton('View'),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined, color: AppColors.textPrimary),
                tooltip: 'Profile',
                color: AppColors.surface,
                offset: const Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.panelBorder),
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await AuthService.logout();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AuthDialog(
                          onAuthenticated: onLogoutSuccess,
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
