import 'package:flutter/material.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

class UnitInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> allowedUnits;
  final Function(String)? onChanged;

  const UnitInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.allowedUnits,
    this.onChanged,
  });

  @override
  State<UnitInputField> createState() => _UnitInputFieldState();
}

class _UnitInputFieldState extends State<UnitInputField> {
  late String _selectedUnit;
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _parseInitialValue();
  }

  @override
  void didUpdateWidget(UnitInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.text != _getCombinedValue()) {
      _parseInitialValue();
    }
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  void _parseInitialValue() {
    String text = widget.controller.text.trim();
    String foundUnit = '';
    
    // Sort units by length descending so 'ms' matches before 's'
    final sortedUnits = List<String>.from(widget.allowedUnits)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final unit in sortedUnits) {
      if (unit.isNotEmpty && text.endsWith(unit)) {
        foundUnit = unit;
        text = text.substring(0, text.length - unit.length).trim();
        break;
      }
    }

    _selectedUnit = widget.allowedUnits.contains(foundUnit) 
        ? foundUnit 
        : (widget.allowedUnits.isNotEmpty ? widget.allowedUnits.first : '');
    
    _internalController.text = text;
  }

  String _getCombinedValue() {
    return '${_internalController.text}$_selectedUnit'.trim();
  }

  void _handleTextChange(String val) {
    String text = val.trim();
    String foundUnit = '';
    
    // Auto-correct if user types a unit
    final sortedUnits = List<String>.from(widget.allowedUnits)
      ..sort((a, b) => b.length.compareTo(a.length));

    bool unitChanged = false;
    for (final unit in sortedUnits) {
      if (unit.isNotEmpty && text.endsWith(unit)) {
        foundUnit = unit;
        text = text.substring(0, text.length - unit.length).trim();
        unitChanged = true;
        break;
      }
    }

    if (unitChanged && widget.allowedUnits.contains(foundUnit)) {
      setState(() {
        _selectedUnit = foundUnit;
        _internalController.text = text;
        _internalController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      });
    }

    widget.controller.text = _getCombinedValue();
    widget.onChanged?.call(widget.controller.text);
  }

  void _handleUnitChange(String? newUnit) {
    if (newUnit != null) {
      setState(() {
        _selectedUnit = newUnit;
      });
      widget.controller.text = _getCombinedValue();
      widget.onChanged?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 36,
          child: TextField(
            controller: _internalController,
            onChanged: _handleTextChange,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: widget.allowedUnits.isEmpty ? null : _buildDropdown(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.panelBorder, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.panelBorder, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.only(right: 4, left: 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.panelBorder)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnit,
          icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
          isDense: true,
          dropdownColor: AppColors.surfaceVariant,
          onChanged: _handleUnitChange,
          items: widget.allowedUnits.map((String unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(
                unit.isEmpty ? '-' : unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
