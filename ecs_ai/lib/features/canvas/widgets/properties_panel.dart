import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';

class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({
    super.key,
    this.selectedComponent,
    this.onComponentUpdate,
  });

  final CircuitComponent? selectedComponent;
  final void Function(CircuitComponent updated)? onComponentUpdate;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  late final TextEditingController _labelController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _valueController = TextEditingController();
    _updateControllers();
  }

  @override
  void didUpdateWidget(PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedComponent != widget.selectedComponent) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (widget.selectedComponent != null) {
      if (_labelController.text != widget.selectedComponent!.label) {
        _labelController.text = widget.selectedComponent!.label;
      }
      if (_valueController.text != widget.selectedComponent!.value) {
        _valueController.text = widget.selectedComponent!.value;
      }
    } else {
      _labelController.clear();
      _valueController.clear();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _submitUpdate() {
    if (widget.selectedComponent == null) return;
    final updated = widget.selectedComponent!.copyWith(
      label: _labelController.text,
      value: _valueController.text,
    );
    widget.onComponentUpdate?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedComponent == null) {
      return Center(
        child: Text(
          'No component selected',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final comp = widget.selectedComponent!;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  comp.type.name.toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Designator (Label)', _labelController),
            const SizedBox(height: 16),
            _buildTextField('Value (e.g. 10k, 5V)', _valueController),
            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.panelBorder),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rotation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.panelBorder),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rotate_left, size: 18),
                        color: AppColors.textPrimary,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final updated = comp.copyWith(
                            rotation: (comp.rotation - 90) % 360,
                          );
                          widget.onComponentUpdate?.call(updated);
                        },
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: AppColors.panelBorder,
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right, size: 18),
                        color: AppColors.textPrimary,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final updated = comp.copyWith(
                            rotation: (comp.rotation + 90) % 360,
                          );
                          widget.onComponentUpdate?.call(updated);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            onChanged: (_) => _submitUpdate(),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.panelBorder,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.panelBorder,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
