import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:ecs_ai/features/canvas/painters/waveform_painter.dart';
import 'package:collection/collection.dart';

class SimulationPanel extends StatelessWidget {
  final int simulationTabIndex;
  final Map<String, Map<String, dynamic>> componentMetrics;
  final List<CircuitComponent> components;
  final String? hoveredComponentId;
  final Function(int) onTabChanged;
  final Function(String?) onHoverComponent;

  const SimulationPanel({
    super.key,
    required this.simulationTabIndex,
    required this.componentMetrics,
    required this.components,
    required this.hoveredComponentId,
    required this.onTabChanged,
    required this.onHoverComponent,
  });

  Widget _buildSimTabButton(String label, int index) {
    final isSelected = simulationTabIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformTab() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CustomPaint(
                  painter: WaveformPainter(),
                  child: Container(),
                ),
              ),
            ),
            Container(
              width: 150,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.panelBorder),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Input Signal', Colors.cyan),
                  const SizedBox(height: 12),
                  _buildLegendItem('Filtered Output', Colors.amber),
                  const SizedBox(height: 12),
                  _buildLegendItem('Control Voltage', Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
        // Coming Soon Overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.panelBorder),
                ),
                child: const Text(
                  'Live Waveform Data Coming Soon',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComponentValuesTab() {
    if (componentMetrics.isEmpty) {
      return const Center(
        child: Text(
          'Run simulation to view component metrics.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Expanded(child: Text('COMP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('I (mA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('V (V)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
                Expanded(child: Text('P (mW)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.2))),
              ],
            ),
          ),
          // Data Rows
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: componentMetrics.entries.map((e) {
                  final compId = e.key;
                  final metrics = e.value;
                  final comp = components.firstWhereOrNull((c) => c.id == compId);
                  
                  if (comp == null) return const SizedBox.shrink();

                  double voltage = (metrics["voltageDrop"] as num?)?.toDouble() ?? 0.0;
                  double current = (metrics["current"] as num?)?.toDouble() ?? 0.0;
                  double power = (metrics["power"] as num?)?.toDouble() ?? 0.0;

                  double currentMa = current * 1000;
                  double powerMw = power * 1000;

                  final cellStyle = TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.9));
                  final isHovered = hoveredComponentId == compId;

                  return MouseRegion(
                    onEnter: (_) => onHoverComponent(compId),
                    onExit: (_) => onHoverComponent(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: isHovered ? AppColors.selection.withValues(alpha: 0.15) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: AppColors.panelBorder.withValues(alpha: 0.1))),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(comp.label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan, fontSize: 14))),
                          Expanded(child: Text(currentMa.toStringAsFixed(2), style: cellStyle)),
                          Expanded(child: Text(voltage.toStringAsFixed(2), style: cellStyle)),
                          Expanded(child: Text(powerMw.toStringAsFixed(2), style: cellStyle.copyWith(color: Colors.cyan))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          // Header
          Container(
            height: AppConstants.panelHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SIMULATION RESULTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const Spacer(),
                // segmented control
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSimTabButton('Waveform Graph', 0),
                      _buildSimTabButton('Component Values', 1),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: simulationTabIndex == 0 
                ? _buildWaveformTab() 
                : _buildComponentValuesTab(),
          ),
        ],
      ),
    );
  }
}
