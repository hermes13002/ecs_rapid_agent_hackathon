import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/models/ide_notification.dart';

class NotificationCard extends StatelessWidget {
  final IdeNotification notification;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: notification.type == 'error'
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.type == 'error'
                    ? Icons.error_outline
                    : Icons.info_outline,
                color: notification.type == 'error'
                    ? AppColors.error
                    : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.type == 'error' ? 'Error' : 'Notification',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDismiss,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
