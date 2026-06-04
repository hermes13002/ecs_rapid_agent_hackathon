import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/core/constants/app_constants.dart';
import 'package:ecs_ai/core/models/component_type.dart';

class ComponentLibraryPanel extends StatefulWidget {
  final String activeTool;
  final Function(ComponentType) onSelectComponent;

  const ComponentLibraryPanel({
    super.key,
    required this.activeTool,
    required this.onSelectComponent,
  });

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  String _componentSearchQuery = '';

  Widget _buildLibraryItem(ComponentType type) {
    final isSelected = widget.activeTool == 'PLACE_${type.name.toUpperCase()}';
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: InkWell(
        onTap: () => widget.onSelectComponent(type),
        hoverColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                type.iconPath,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  isSelected ? Colors.black : AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.label,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentLibrary() {
    final grouped = <ComponentCategory, List<ComponentType>>{};
    for (final type in ComponentType.values) {
      if (_componentSearchQuery.isNotEmpty && !type.label.toLowerCase().contains(_componentSearchQuery.toLowerCase())) {
        continue;
      }
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 0),
      children: grouped.entries.map((entry) {
        String catName = entry.key.name;
        catName = catName[0].toUpperCase() + catName.substring(1) + ' Components';
        
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            controlAffinity: ListTileControlAffinity.leading,
            iconColor: AppColors.textSecondary,
            collapsedIconColor: AppColors.textSecondary,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            title: Text(
              catName,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: entry.value.map((type) => _buildLibraryItem(type)).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: AppConstants.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surfaceVariant,
          alignment: Alignment.centerLeft,
          child: Text(
            'COMPONENTS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(8),
          color: AppColors.panel,
          child: TextField(
            onChanged: (val) {
              setState(() {
                _componentSearchQuery = val;
              });
            },
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Filter library...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        Expanded(child: _buildComponentLibrary()),
      ],
    );
  }
}
