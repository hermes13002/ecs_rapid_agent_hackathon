import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class SimulationBottomToolbar extends StatelessWidget {
  final String simulationStatus;
  final bool isSimulationExpanded;
  final VoidCallback onStop;
  final VoidCallback onRun;
  final VoidCallback onToggleExpand;
  final bool hasDesignErrors;

  const SimulationBottomToolbar({
    super.key,
    required this.simulationStatus,
    required this.isSimulationExpanded,
    required this.onStop,
    required this.onRun,
    required this.onToggleExpand,
    this.hasDesignErrors = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          top: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasDesignErrors ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: hasDesignErrors ? AppColors.error : Colors.cyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            hasDesignErrors ? 'Design Errors' : 'No Design Errors',
            style: TextStyle(
              color: hasDesignErrors ? AppColors.error : Colors.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (simulationStatus != 'Ready') ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onStop,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.stop_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: AppColors.error,
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
            const SizedBox(width: 12),
          ],
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRun,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFD4F1F4,
                  ), // Light cyan matching the image
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.play_arrow, color: Color(0xFF005B7F), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'RUN SIMULATION',
                      style: TextStyle(
                        color: Color(
                          0xFF005B7F,
                        ), // Dark cyan/blue matching the image
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
          // Simulation Expand/Collapse Toggle
          IconButton(
            icon: Icon(
              isSimulationExpanded ? Icons.analytics : Icons.analytics_outlined,
              size: 22,
            ),
            color: AppColors.textSecondary,
            onPressed: onToggleExpand,
          ),
        ],
      ),
    );
  }
}
