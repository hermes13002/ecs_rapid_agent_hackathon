import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class FloatingToolbar extends StatelessWidget {
  final String activeTool;
  final bool hasUndo;
  final bool hasSelection;
  final Function(String) setTool;
  final VoidCallback onUndo;
  final VoidCallback onDelete;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;

  const FloatingToolbar({
    super.key,
    required this.activeTool,
    required this.hasUndo,
    required this.hasSelection,
    required this.setTool,
    required this.onUndo,
    required this.onDelete,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onRotateLeft,
    required this.onRotateRight,
  });

  Widget _floatingToolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 20,
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: isActive ? Colors.white : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.95),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _floatingToolbarButton(Icons.near_me_outlined, 'Select', () => setTool('SELECT'), isActive: activeTool == 'SELECT'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.timeline, 'Wire', () => setTool('WIRE'), isActive: activeTool == 'WIRE'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.pan_tool_outlined, 'Pan', () => setTool('PAN'), isActive: activeTool == 'PAN'),
          const SizedBox(height: 4),
          Container(width: 20, height: 1, color: AppColors.panelBorder, margin: const EdgeInsets.symmetric(vertical: 6)),
          const SizedBox(height: 4),
          Opacity(
            opacity: !hasUndo ? 0.5 : 1.0,
            child: _floatingToolbarButton(Icons.undo_outlined, 'Undo AI Action', !hasUndo ? () {} : onUndo, isActive: false),
          ),
          if (hasSelection) ...[
            const SizedBox(height: 6),
            _floatingToolbarButton(Icons.rotate_left, 'Rotate Left', onRotateLeft, isActive: false),
            const SizedBox(height: 6),
            _floatingToolbarButton(Icons.rotate_right, 'Rotate Right', onRotateRight, isActive: false),
            const SizedBox(height: 6),
            _floatingToolbarButton(Icons.delete_outline, 'Delete Selected', onDelete, isActive: false),
          ],
          const SizedBox(height: 4),
          Container(width: 20, height: 1, color: AppColors.panelBorder, margin: const EdgeInsets.symmetric(vertical: 6)),
          const SizedBox(height: 4),
          _floatingToolbarButton(Icons.zoom_in, 'Zoom In', onZoomIn, isActive: activeTool == 'ZOOM_IN'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.zoom_out, 'Zoom Out', onZoomOut, isActive: activeTool == 'ZOOM_OUT'),
          const SizedBox(height: 6),
          _floatingToolbarButton(Icons.fit_screen_outlined, 'Fit', onResetZoom),
        ],
      ),
    );
  }
}
