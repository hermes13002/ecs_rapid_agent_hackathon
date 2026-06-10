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
          top: BorderSide(color: AppColors.panelBorder.withOpacity(0.3)),
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
                    color: AppColors.error.withOpacity(0.15),
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
              onTap: () {
                _showSimulationSettingsModal(context, simulationConfig, onConfigChanged);
              },
              child: Tooltip(
                message: 'Simulation Settings',
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
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

void _showSimulationSettingsModal(
  BuildContext context,
  Map<String, dynamic> config,
  ValueChanged<Map<String, dynamic>> onConfigChanged,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Simulation Settings',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: _SimulationSettingsModal(
            initialConfig: config,
            onConfigChanged: onConfigChanged,
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          )),
          child: child,
        ),
      );
    },
  );
}

class _SimulationSettingsModal extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onConfigChanged;

  const _SimulationSettingsModal({
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<_SimulationSettingsModal> createState() => _SimulationSettingsModalState();
}

class _SimulationSettingsModalState extends State<_SimulationSettingsModal> {
  late Map<String, dynamic> _config;
  late TextEditingController _stopCtrl;
  late TextEditingController _stepCtrl;
  late TextEditingController _ptsCtrl;
  late TextEditingController _fstartCtrl;
  late TextEditingController _fstopCtrl;

  @override
  void initState() {
    super.initState();
    _config = Map<String, dynamic>.from(widget.initialConfig);
    _stopCtrl = TextEditingController(text: _config['stop']?.toString() ?? '100ms');
    _stepCtrl = TextEditingController(text: _config['step']?.toString() ?? '1ms');
    _ptsCtrl = TextEditingController(text: _config['points']?.toString() ?? '10');
    _fstartCtrl = TextEditingController(text: _config['fstart']?.toString() ?? '1');
    _fstopCtrl = TextEditingController(text: _config['fstop']?.toString() ?? '100k');
  }

  @override
  void dispose() {
    _stopCtrl.dispose();
    _stepCtrl.dispose();
    _ptsCtrl.dispose();
    _fstartCtrl.dispose();
    _fstopCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final type = _config['type'];
    if (type == 'tran') {
      _config['stop'] = _stopCtrl.text;
      _config['step'] = _stepCtrl.text;
    } else if (type == 'ac') {
      _config['points'] = _ptsCtrl.text;
      _config['fstart'] = _fstartCtrl.text;
      _config['fstop'] = _fstopCtrl.text;
    }
    widget.onConfigChanged(_config);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Simulation Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.panelBorder),
          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildConfigForm(),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _apply,
                  child: const Text('Apply Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigForm() {
    final type = _config['type'] as String? ?? 'op';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown(
          label: 'Analysis Type',
          value: type,
          items: const [
            DropdownMenuItem(value: 'op', child: Text('Operating Point (DC)')),
            DropdownMenuItem(value: 'tran', child: Text('Transient (Time Domain)')),
            DropdownMenuItem(value: 'ac', child: Text('AC Sweep (Frequency)')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _config['type'] = val;
                if (val == 'tran') {
                  _config['step'] ??= '1ms';
                  _config['stop'] ??= '100ms';
                } else if (val == 'ac') {
                  _config['points'] ??= '10';
                  _config['fstart'] ??= '1';
                  _config['fstop'] ??= '100k';
                }
              });
            }
          },
        ),
        const SizedBox(height: 20),
        if (type == 'tran') ...[
          Text('Transient Settings', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          _buildInputRow('Stop Time', _stopCtrl, 'e.g. 100ms'),
          const SizedBox(height: 12),
          _buildInputRow('Time Step', _stepCtrl, 'e.g. 1ms'),
        ] else if (type == 'ac') ...[
          Text('AC Sweep Settings', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          _buildInputRow('Points/Decade', _ptsCtrl, 'e.g. 10'),
          const SizedBox(height: 12),
          _buildInputRow('Start Freq', _fstartCtrl, 'e.g. 1'),
          const SizedBox(height: 12),
          _buildInputRow('Stop Freq', _fstopCtrl, 'e.g. 100k'),
        ] else ...[
          const Text('No additional settings required for OP.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.panel,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              onChanged: onChanged,
              items: items,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller, String hint) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
        ),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.panelBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.panelBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
