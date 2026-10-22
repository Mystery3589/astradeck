import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck_models.dart';
import '../services/profile_service.dart';
import '../theme/astradeck_theme.dart';

class ProfileSettingsSheet extends StatefulWidget {
  final DeckProfile profile;

  const ProfileSettingsSheet({super.key, required this.profile});

  static Future<void> show(BuildContext context, DeckProfile profile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileSettingsSheet(profile: profile),
    );
  }

  @override
  State<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _windowTriggerController;

  late int _rows;
  late int _cols;
  late int _defaultPageIndex;
  late bool _showLabels;
  late double _spacing;
  late double _radius;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.name);
    _descController = TextEditingController(text: p.description);
    _windowTriggerController = TextEditingController(text: p.autoSwitchWindowTitle ?? '');

    _rows = p.gridRows;
    _cols = p.gridCols;
    _defaultPageIndex = p.defaultPageIndex;

    final appConf = p.appearanceConfig;
    _showLabels = appConf['showLabels'] as bool? ?? true;
    _spacing = (appConf['buttonSpacing'] as num?)?.toDouble() ?? 12.0;
    _radius = (appConf['buttonRadius'] as num?)?.toDouble() ?? 16.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _windowTriggerController.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final service = context.read<ProfileService>();
    final newName = _nameController.text.trim();
    final newDesc = _descController.text.trim();
    final trigger = _windowTriggerController.text.trim();

    service.updateProfileMetadata(
      widget.profile.id,
      name: newName.isEmpty ? widget.profile.name : newName,
      description: newDesc,
      rows: _rows,
      cols: _cols,
      autoSwitchWindowTitle: trigger.isEmpty ? null : trigger,
      defaultPageIndex: _defaultPageIndex,
      appearanceConfig: {
        ...widget.profile.appearanceConfig,
        'showLabels': _showLabels,
        'buttonSpacing': _spacing,
        'buttonRadius': _radius,
      },
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: themeBundle.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: themeBundle.borderColor, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: themeBundle.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Settings',
                        style: TextStyle(
                          color: themeBundle.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Configure grid, appearance & triggers',
                        style: TextStyle(
                          color: themeBundle.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: themeBundle.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Name & Description
                _buildSectionHeader('PROFILE IDENTITY', themeBundle),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: themeBundle.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Profile Name',
                    labelStyle: TextStyle(color: themeBundle.textSecondary),
                    filled: true,
                    fillColor: themeBundle.surfaceElevated,
                    prefixIcon: Icon(Icons.label_outline_rounded, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  style: TextStyle(color: themeBundle.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: themeBundle.textSecondary),
                    filled: true,
                    fillColor: themeBundle.surfaceElevated,
                    prefixIcon: Icon(Icons.notes_rounded, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Grid Dimensions
                _buildSectionHeader('GRID DIMENSIONS', themeBundle),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeBundle.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: themeBundle.borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.table_rows_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Grid Rows: $_rows', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [2, 3, 4, 5].map((val) {
                              final isSelected = _rows == val;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text('$val'),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _rows = val),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.view_column_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Grid Columns: $_cols', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [2, 3, 4, 5].map((val) {
                              final isSelected = _cols == val;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text('$val'),
                                  selected: isSelected,
                                  onSelected: (_) => setState(() => _cols = val),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Auto-Profile Switch Trigger
                _buildSectionHeader('AUTO-PROFILE TRIGGER (PC WINDOW)', themeBundle),
                const SizedBox(height: 8),
                TextField(
                  controller: _windowTriggerController,
                  style: TextStyle(color: themeBundle.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Active Window Match (e.g. OBS, Blender, VS Code)',
                    hintText: 'e.g. "OBS Studio" or "Code"',
                    hintStyle: TextStyle(color: themeBundle.textSecondary.withValues(alpha: 0.5)),
                    labelStyle: TextStyle(color: themeBundle.textSecondary),
                    filled: true,
                    fillColor: themeBundle.surfaceElevated,
                    prefixIcon: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                    helperText: 'AstraDeck switches to this profile when this PC app is focused.',
                    helperStyle: TextStyle(color: themeBundle.textSecondary, fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeBundle.borderColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Appearance & Spacing
                _buildSectionHeader('APPEARANCE & SPACING', themeBundle),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeBundle.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: themeBundle.borderColor),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Show Button Labels', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text('Display titles under action icons', style: TextStyle(color: themeBundle.textSecondary, fontSize: 12)),
                        value: _showLabels,
                        onChanged: (val) => setState(() => _showLabels = val),
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Button Spacing: ${_spacing.toInt()}px', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w500)),
                                Slider(
                                  value: _spacing,
                                  min: 6,
                                  max: 20,
                                  divisions: 14,
                                  onChanged: (v) => setState(() => _spacing = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Corner Radius: ${_radius.toInt()}px', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w500)),
                                Slider(
                                  value: _radius,
                                  min: 4,
                                  max: 28,
                                  divisions: 12,
                                  onChanged: (v) => setState(() => _radius = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Save button footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text(
                  'Save Profile Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AstraThemeBundle bundle) {
    return Text(
      title,
      style: TextStyle(
        color: bundle.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
