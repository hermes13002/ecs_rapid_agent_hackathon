import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/services/auth_service.dart';
import 'package:ecs_ai/features/auth/widgets/auth_dialog.dart';
import 'package:ecs_ai/features/canvas/widgets/simulation_bottom_toolbar.dart';

class WorkspaceToolbar extends StatelessWidget {
  final VoidCallback onLogoutSuccess;
  final String simulationStatus;
  final bool isSimulationExpanded;
  final VoidCallback onStop;
  final VoidCallback onRun;
  final VoidCallback onToggleExpand;
  final bool hasDesignErrors;
  final Map<String, dynamic> simulationConfig;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  const WorkspaceToolbar({
    super.key, 
    required this.onLogoutSuccess,
    required this.simulationStatus,
    required this.isSimulationExpanded,
    required this.onStop,
    required this.onRun,
    required this.onToggleExpand,
    this.hasDesignErrors = false,
    required this.simulationConfig,
    required this.onConfigChanged,
  });

  Widget _buildMenuButton(BuildContext context, String title, List<PopupMenuEntry<String>> items) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 30),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
      itemBuilder: (context) => items,
      onSelected: (value) {
        // Functionality placeholder
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSimError = simulationStatus.startsWith('Error:');
    final hasAnyError = hasDesignErrors || isSimError;
    
    String errorText = 'Ready';
    if (hasDesignErrors) {
      errorText = 'Design Errors';
    } else if (isSimError) {
      String msg = simulationStatus.replaceFirst('Error: ', '');
      if (msg.length > 30) msg = '${msg.substring(0, 30)}...';
      errorText = 'Sim Error: $msg';
    } else if (simulationStatus != 'Ready') {
      errorText = simulationStatus;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: AppConstants.toolbarHeight,
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'ECS-AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 24),
              _buildMenuButton(context, 'File', [
                const PopupMenuItem(value: 'new', child: Text('New Project')),
                const PopupMenuItem(value: 'open', child: Text('Open...')),
                const PopupMenuItem(value: 'save', child: Text('Save')),
              ]),
              _buildMenuButton(context, 'Edit', [
                const PopupMenuItem(value: 'undo', child: Text('Undo')),
                const PopupMenuItem(value: 'redo', child: Text('Redo')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'cut', child: Text('Cut')),
                const PopupMenuItem(value: 'copy', child: Text('Copy')),
                const PopupMenuItem(value: 'paste', child: Text('Paste')),
              ]),
              _buildMenuButton(context, 'Simulate', [
                const PopupMenuItem(value: 'run', child: Text('Run Simulation')),
                const PopupMenuItem(value: 'stop', child: Text('Stop Simulation')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'settings', child: Text('Simulation Settings...')),
              ]),
              _buildMenuButton(context, 'View', [
                const PopupMenuItem(value: 'zoom_in', child: Text('Zoom In')),
                const PopupMenuItem(value: 'zoom_out', child: Text('Zoom Out')),
                const PopupMenuItem(value: 'fit', child: Text('Fit to Screen')),
              ]),
              const Spacer(),
              
              // --- SIMULATION CONTROLS ---
              if (hasAnyError)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: hasDesignErrors ? 'There are logic or schematic design errors.' : simulationStatus,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          errorText,
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

              if (simulationStatus != 'Ready' && !hasAnyError)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onStop,
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.stop_rounded, color: AppColors.error, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'STOP',
                              style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    showSimulationSettingsModal(context, simulationConfig, onConfigChanged);
                  },
                  child: Tooltip(
                    message: 'Simulation Settings',
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            (simulationConfig['type'] as String? ?? 'op').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onRun,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.play_arrow, color: Colors.black, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'RUN',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: 'Toggle Simulation Panel',
                child: InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSimulationExpanded ? AppColors.panel : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      isSimulationExpanded ? Icons.analytics : Icons.analytics_outlined,
                      color: isSimulationExpanded ? Colors.white : AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              // --- END SIMULATION CONTROLS ---

              const SizedBox(width: 16),
              Container(height: 24, width: 1, color: AppColors.panelBorder),
              const SizedBox(width: 16),
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
