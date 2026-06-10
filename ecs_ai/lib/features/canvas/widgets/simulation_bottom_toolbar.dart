import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class SimulationBottomToolbar extends StatelessWidget {
  final String simulationStatus;
  final bool isSimulationExpanded;
  final VoidCallback onStop;
  final VoidCallback onRun;
  final VoidCallback onToggleExpand;
  final bool hasDesignErrors;
  final Map<String, dynamic> simulationConfig;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  const SimulationBottomToolbar({
    super.key,
    required this.simulationStatus,
    required this.isSimulationExpanded,
    required this.onStop,
    required this.onRun,
    required this.onToggleExpand,
    this.hasDesignErrors = false,
    required this.simulationConfig,
    required this.onConfigChanged,
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
            color: hasDesignErrors ? AppColors.error : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            hasDesignErrors ? 'Design Errors' : 'No Design Errors',
            style: TextStyle(
              color: hasDesignErrors ? AppColors.error : Colors.white,
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
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: simulationConfig['type'] as String? ?? 'op',
              dropdownColor: AppColors.surfaceVariant,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'op', child: Text('OP')),
                DropdownMenuItem(value: 'tran', child: Text('TRANSIENT')),
                DropdownMenuItem(value: 'ac', child: Text('AC SWEEP')),
              ],
              onChanged: (val) {
                if (val != null) {
                  final Map<String, dynamic> newConfig = {'type': val};
                  if (val == 'tran') {
                    newConfig['step'] = simulationConfig['step'] ?? '1ms';
                    newConfig['stop'] = simulationConfig['stop'] ?? '100ms';
                  } else if (val == 'ac') {
                    newConfig['points'] = simulationConfig['points'] ?? '10';
                    newConfig['fstart'] = simulationConfig['fstart'] ?? '1';
                    newConfig['fstop'] = simulationConfig['fstop'] ?? '100k';
                  }
                  onConfigChanged(newConfig);
                }
              },
            ),
          ),
          if (simulationConfig['type'] == 'tran') ...[
            const SizedBox(width: 8),
            _SimInputField(label: 'Step', configKey: 'step', config: simulationConfig, onChanged: onConfigChanged),
            const SizedBox(width: 4),
            _SimInputField(label: 'Stop', configKey: 'stop', config: simulationConfig, onChanged: onConfigChanged),
          ] else if (simulationConfig['type'] == 'ac') ...[
            const SizedBox(width: 8),
            _SimInputField(label: 'Pts', configKey: 'points', config: simulationConfig, onChanged: onConfigChanged),
            const SizedBox(width: 4),
            _SimInputField(label: 'Start', configKey: 'fstart', config: simulationConfig, onChanged: onConfigChanged),
            const SizedBox(width: 4),
            _SimInputField(label: 'Stop', configKey: 'fstop', config: simulationConfig, onChanged: onConfigChanged),
          ],
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
          // Simulation Expand/Collapse Toggle
          Tooltip(
            message: 'Toggle Simulation Panel',
            preferBelow: false,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSimulationExpanded ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isSimulationExpanded ? Icons.analytics : Icons.analytics_outlined,
                  color: isSimulationExpanded ? Colors.black : AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimInputField extends StatefulWidget {
  final String label;
  final String configKey;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _SimInputField({
    required this.label,
    required this.configKey,
    required this.config,
    required this.onChanged,
  });

  @override
  State<_SimInputField> createState() => _SimInputFieldState();
}

class _SimInputFieldState extends State<_SimInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.config[widget.configKey]?.toString() ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _submit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SimInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config[widget.configKey] != oldWidget.config[oldWidget.configKey]) {
      final newVal = widget.config[widget.configKey]?.toString() ?? '';
      if (_controller.text != newVal && !_focusNode.hasFocus) {
        _controller.text = newVal;
      }
    }
  }

  void _submit() {
    final newConfig = Map<String, dynamic>.from(widget.config);
    newConfig[widget.configKey] = _controller.text;
    widget.onChanged(newConfig);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55,
      height: 28,
      margin: const EdgeInsets.only(right: 4),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.panelBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
