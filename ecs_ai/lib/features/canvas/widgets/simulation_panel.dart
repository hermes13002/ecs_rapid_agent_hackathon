import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';

class SimulationPanel extends StatefulWidget {
  final int simulationTabIndex;
  final Map<String, Map<String, dynamic>> componentMetrics;
  final List<CircuitComponent> components;
  final Map<String, List<double>>? timeSeriesData;
  final String? hoveredComponentId;
  final Function(int) onTabChanged;
  final Function(String?) onHoverComponent;

  const SimulationPanel({
    super.key,
    required this.simulationTabIndex,
    required this.componentMetrics,
    required this.components,
    this.timeSeriesData,
    required this.hoveredComponentId,
    required this.onTabChanged,
    required this.onHoverComponent,
  });

  @override
  State<SimulationPanel> createState() => _SimulationPanelState();
}

class _SimulationPanelState extends State<SimulationPanel> {
  final Set<String> _hiddenTraces = {};

  Widget _buildSimTabButton(String label, int index) {
    final isSelected = widget.simulationTabIndex == index;
    return GestureDetector(
      onTap: () => widget.onTabChanged(index),
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

  Widget _buildInteractiveLegendItem(
    String label,
    Color color,
    bool isVisible,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isVisible ? color : AppColors.panelBorder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isVisible
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withOpacity(0.5),
                fontWeight: isVisible ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              size: 14,
            ),
            color: isVisible
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.5),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                if (isVisible) {
                  _hiddenTraces.add(label);
                } else {
                  _hiddenTraces.remove(label);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformTab() {
    final hasTime =
        widget.timeSeriesData != null &&
        widget.timeSeriesData!.containsKey('time');
    final hasFreq =
        widget.timeSeriesData != null &&
        widget.timeSeriesData!.containsKey('frequency');
    final hasData =
        widget.timeSeriesData != null &&
        widget.timeSeriesData!.isNotEmpty &&
        (hasTime || hasFreq);

    final waveformColors = [
      Colors.cyan,
      Colors.amber,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
    ];

    List<LineChartBarData> lineBars = [];
    List<Widget> legendItems = [];
    double minX = 0,
        maxX = 0,
        minY = double.infinity,
        maxY = double.negativeInfinity;

    if (hasData) {
      final xKey = hasTime ? 'time' : 'frequency';
      final xArray = widget.timeSeriesData![xKey]!;
      if (xArray.isNotEmpty) {
        minX = xArray.first;
        maxX = xArray.last;
      }

      int colorIndex = 0;
      for (final entry in widget.timeSeriesData!.entries) {
        if (entry.key == 'time' || entry.key == 'frequency') continue;

        final isVisible = !_hiddenTraces.contains(entry.key);
        final color = waveformColors[colorIndex % waveformColors.length];

        legendItems.add(
          _buildInteractiveLegendItem(entry.key, color, isVisible),
        );

        if (isVisible) {
          final yValues = entry.value;
          List<FlSpot> spots = [];

          for (int i = 0; i < xArray.length && i < yValues.length; i++) {
            spots.add(FlSpot(xArray[i], yValues[i]));
            if (yValues[i] < minY) minY = yValues[i];
            if (yValues[i] > maxY) maxY = yValues[i];
          }

          lineBars.add(
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          );
        }

        colorIndex++;
      }
    }

    if (minY == double.infinity) minY = -1;
    if (maxY == double.negativeInfinity) maxY = 1;
    final yRange = maxY - minY;
    final yPadding = yRange == 0 ? 1.0 : yRange * 0.1;
    minY -= yPadding;
    maxY += yPadding;

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: hasData
                    ? LineChart(
                        LineChartData(
                          lineBarsData: lineBars,
                          minX: minX,
                          maxX: maxX,
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: yRange > 0
                                ? (yRange / 5).clamp(0.01, double.infinity)
                                : 1,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: AppColors.panelBorder.withOpacity(0.5),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (value) => FlLine(
                              color: AppColors.panelBorder.withOpacity(0.5),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: (maxX - minX) > 0
                                    ? ((maxX - minX) / 5)
                                    : 1,
                                getTitlesWidget: (value, meta) {
                                  final isFreq = hasFreq;
                                  final label = isFreq
                                      ? (value >= 1000
                                            ? '${(value / 1000).toStringAsFixed(1)}kHz'
                                            : '${value.toStringAsFixed(0)}Hz')
                                      : '${(value * 1000).toStringAsFixed(1)}ms';
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: yRange > 0
                                    ? (yRange / 5).clamp(0.01, double.infinity)
                                    : 1,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toStringAsFixed(1)}V',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.right,
                                  );
                                },
                                reservedSize: 40,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: AppColors.panelBorder),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final isFreq = hasFreq;
                                  final xLabel = isFreq
                                      ? (spot.x >= 1000
                                            ? '${(spot.x / 1000).toStringAsFixed(1)}kHz'
                                            : '${spot.x.toStringAsFixed(0)}Hz')
                                      : '${(spot.x * 1000).toStringAsFixed(2)}ms';
                                  return LineTooltipItem(
                                    '${spot.y.toStringAsFixed(3)}V\n@ $xLabel',
                                    TextStyle(
                                      color: lineBars[spot.barIndex].color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No Time-Series Data Available.\nRun a Transient Simulation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ),
            Container(
              width: 160,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.panelBorder)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SIGNALS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (legendItems.isNotEmpty)
                    ...legendItems
                  else
                    const Text(
                      'No Signals',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComponentValuesTab() {
    if (widget.componentMetrics.isEmpty) {
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
              border: Border(
                bottom: BorderSide(
                  color: AppColors.panelBorder.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'COMP',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'I (mA)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'V (V)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'P (mW)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data Rows
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: widget.componentMetrics.entries.map((e) {
                  final compId = e.key;
                  final metrics = e.value;
                  final comp = widget.components.firstWhereOrNull(
                    (c) => c.id == compId,
                  );

                  if (comp == null) return const SizedBox.shrink();

                  double voltage =
                      (metrics["voltageDrop"] as num?)?.toDouble() ?? 0.0;
                  double current =
                      (metrics["current"] as num?)?.toDouble() ?? 0.0;
                  double power = (metrics["power"] as num?)?.toDouble() ?? 0.0;

                  double currentMa = current * 1000;
                  double powerMw = power * 1000;

                  final cellStyle = TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    color: AppColors.textSecondary.withOpacity(0.9),
                  );
                  final isHovered = widget.hoveredComponentId == compId;

                  return MouseRegion(
                    onEnter: (_) => widget.onHoverComponent(compId),
                    onExit: (_) => widget.onHoverComponent(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? AppColors.selection.withOpacity(0.15)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.panelBorder.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              comp.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              currentMa.toStringAsFixed(2),
                              style: cellStyle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              voltage.toStringAsFixed(2),
                              style: cellStyle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              powerMw.toStringAsFixed(2),
                              style: cellStyle.copyWith(color: Colors.cyan),
                            ),
                          ),
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
                const Icon(Icons.bar_chart, color: Colors.white, size: 18),
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
            child: widget.simulationTabIndex == 0
                ? _buildWaveformTab()
                : _buildComponentValuesTab(),
          ),
        ],
      ),
    );
  }
}
