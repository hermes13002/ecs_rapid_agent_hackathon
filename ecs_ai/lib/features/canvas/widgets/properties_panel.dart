import 'package:ecs_ai/core/models/component_type.dart';
import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/models/circuit_component.dart';

enum SourceType { dc, ac, transient }

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

  SourceType _sourceMode = SourceType.dc;
  late final TextEditingController _dcValueCtrl;
  late final TextEditingController _acMagCtrl;
  late final TextEditingController _acPhaseCtrl;
  late final TextEditingController _tranAmpCtrl;
  late final TextEditingController _tranFreqCtrl;
  late final TextEditingController _tranOffsetCtrl;
  String _tranType = 'SINE';

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _valueController = TextEditingController();
    _dcValueCtrl = TextEditingController();
    _acMagCtrl = TextEditingController();
    _acPhaseCtrl = TextEditingController();
    _tranAmpCtrl = TextEditingController();
    _tranFreqCtrl = TextEditingController();
    _tranOffsetCtrl = TextEditingController();
    _updateControllers();
  }

  @override
  void didUpdateWidget(PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedComponent != widget.selectedComponent) {
      _updateControllers();
    }
  }

  void _parseSourceValue(String value) {
    final v = value.toUpperCase();
    if (v.contains('SINE') || v.contains('PULSE')) {
      _sourceMode = SourceType.transient;
      _tranType = v.contains('SINE') ? 'SINE' : 'PULSE';
      
      final regex = RegExp(r'(SINE|PULSE)\((.*?)\)');
      final match = regex.firstMatch(v);
      if (match != null) {
        final parts = match.group(2)!.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) _tranOffsetCtrl.text = parts[0];
        if (parts.length > 1) _tranAmpCtrl.text = parts[1];
        if (parts.length > 2) _tranFreqCtrl.text = parts[2];
      }
      
      final acRegex = RegExp(r'AC\s+([\d\.]+)');
      final acMatch = acRegex.firstMatch(v);
      if (acMatch != null) _acMagCtrl.text = acMatch.group(1)!;

    } else if (v.contains('AC')) {
      _sourceMode = SourceType.ac;
      final regex = RegExp(r'AC\s+([\d\.]+)(\s+([\d\.]+))?');
      final match = regex.firstMatch(v);
      if (match != null) {
        _acMagCtrl.text = match.group(1)!;
        if (match.group(3) != null) _acPhaseCtrl.text = match.group(3)!;
      }
    } else {
      _sourceMode = SourceType.dc;
      final regex = RegExp(r'DC\s+([\d\.]+)');
      final match = regex.firstMatch(v);
      if (match != null) {
        _dcValueCtrl.text = match.group(1)!;
      } else {
        _dcValueCtrl.text = value; 
      }
    }
  }

  void _updateControllers() {
    if (widget.selectedComponent != null) {
      final comp = widget.selectedComponent!;
      if (_labelController.text != comp.label) {
        _labelController.text = comp.label;
      }
      if (_valueController.text != comp.value) {
        _valueController.text = comp.value;
        if (comp.type == ComponentType.voltageSource || comp.type == ComponentType.currentSource) {
          _parseSourceValue(comp.value);
        }
      }
    } else {
      _labelController.clear();
      _valueController.clear();
      _dcValueCtrl.clear();
      _acMagCtrl.clear();
      _acPhaseCtrl.clear();
      _tranAmpCtrl.clear();
      _tranFreqCtrl.clear();
      _tranOffsetCtrl.clear();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _dcValueCtrl.dispose();
    _acMagCtrl.dispose();
    _acPhaseCtrl.dispose();
    _tranAmpCtrl.dispose();
    _tranFreqCtrl.dispose();
    _tranOffsetCtrl.dispose();
    super.dispose();
  }

  void _submitUpdate() {
    if (widget.selectedComponent == null) return;
    
    String newValue = _valueController.text;
    
    if (widget.selectedComponent!.type == ComponentType.voltageSource || 
        widget.selectedComponent!.type == ComponentType.currentSource) {
      if (_sourceMode == SourceType.dc) {
        newValue = _dcValueCtrl.text.isNotEmpty ? 'DC ${_dcValueCtrl.text}' : 'DC 0';
      } else if (_sourceMode == SourceType.ac) {
        final phase = _acPhaseCtrl.text.isNotEmpty ? ' ${_acPhaseCtrl.text}' : '';
        final mag = _acMagCtrl.text.isNotEmpty ? _acMagCtrl.text : '1';
        newValue = 'DC 0 AC $mag$phase';
      } else if (_sourceMode == SourceType.transient) {
        final offset = _tranOffsetCtrl.text.isNotEmpty ? _tranOffsetCtrl.text : '0';
        final amp = _tranAmpCtrl.text.isNotEmpty ? _tranAmpCtrl.text : '1';
        final freq = _tranFreqCtrl.text.isNotEmpty ? _tranFreqCtrl.text : '1k';
        final acPart = _acMagCtrl.text.isNotEmpty ? 'AC ${_acMagCtrl.text} ' : '';
        newValue = 'DC 0 $acPart$_tranType($offset $amp $freq)';
      }
      _valueController.text = newValue;
    }

    final updated = widget.selectedComponent!.copyWith(
      label: _labelController.text,
      value: newValue,
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
            if (comp.type == ComponentType.voltageSource || comp.type == ComponentType.currentSource)
              _buildSourceConfigurator()
            else
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

  Widget _buildSourceConfigurator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Source Setup',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: Row(
            children: [
              _buildTab(SourceType.dc, 'DC'),
              _buildTab(SourceType.ac, 'AC Sweep'),
              _buildTab(SourceType.transient, 'Transient'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_sourceMode == SourceType.dc) ...[
          _buildTextField('DC Value (V/A)', _dcValueCtrl),
        ] else if (_sourceMode == SourceType.ac) ...[
          Row(
            children: [
              Expanded(child: _buildTextField('Magnitude', _acMagCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Phase (deg)', _acPhaseCtrl)),
            ],
          ),
        ] else if (_sourceMode == SourceType.transient) ...[
          _buildWaveTypeDropdown(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Amplitude', _tranAmpCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('Offset', _tranOffsetCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField('Frequency (Hz)', _tranFreqCtrl),
        ],
      ],
    );
  }

  Widget _buildTab(SourceType type, String text) {
    final isSelected = _sourceMode == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _sourceMode = type;
            _submitUpdate();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waveform Type',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _tranType,
              isExpanded: true,
              dropdownColor: AppColors.panel,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _tranType = val;
                    _submitUpdate();
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'SINE', child: Text('Sine Wave')),
                DropdownMenuItem(value: 'PULSE', child: Text('Pulse Wave')),
              ],
            ),
          ),
        ),
      ],
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
