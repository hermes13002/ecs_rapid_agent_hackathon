import 'package:flutter/material.dart';

import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';

/// reusable dark panel with title header and animated collapse logic
class PanelContainer extends StatelessWidget {
  const PanelContainer({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
    this.isExpanded = true,
    this.onToggle,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;
  final bool isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(
          right: BorderSide(color: AppColors.panelBorder),
          left: BorderSide(color: AppColors.panelBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _buildHeader(context),
          if (isExpanded) const Divider(height: 1),
          if (isExpanded)
            Expanded(
              child: padding != null
                  ? Padding(padding: padding!, child: child)
                  : child,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        height: AppConstants.panelHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.surfaceVariant,
        child: Row(
          children: [
            if (onToggle != null) ...[
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ] else ...[
              const SizedBox(width: 4), // visual padding if no arrow
            ],
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
