import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/deck_models.dart';
import '../../services/profile_service.dart';
import '../../theme/astradeck_theme.dart';
import '../../widgets/profile_settings_sheet.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final themeBundle = AstraThemeBundle.of(context);
    final profiles = profileService.profiles;

    return Scaffold(
      backgroundColor: themeBundle.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profiles & Layouts',
              style: TextStyle(
                color: themeBundle.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              '${profiles.length} profiles configured • Drag to reorder',
              style: TextStyle(color: themeBundle.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Profile (JSON)',
            onPressed: () => _showImportDialog(context, profileService),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Active Profile Settings',
            onPressed: () => ProfileSettingsSheet.show(context, profileService.currentProfile),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProfileDialog(context, profileService),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: profiles.length,
        onReorderItem: (oldIndex, newIndex) => profileService.reorderProfiles(oldIndex, newIndex),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final isActive = profile.id == profileService.activeProfileId;

          return _ProfileCard(
            key: ValueKey(profile.id),
            profile: profile,
            isActive: isActive,
            index: index,
            onSelect: () => profileService.setActiveProfile(profile.id),
            onSettings: () => ProfileSettingsSheet.show(context, profile),
            onDuplicate: () => profileService.duplicateProfile(profile.id),
            onExport: () => _exportProfile(context, profileService, profile),
            onDelete: profiles.length > 1
                ? () => _confirmDelete(context, profileService, profile)
                : null,
          );
        },
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context, ProfileService service) {
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int rows = 3;
    int cols = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: themeBundle.cardBg,
          title: Text('Create New Profile', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: themeBundle.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Profile Name',
                    hintText: 'e.g. Gaming, Video Editing, Coding',
                    labelStyle: TextStyle(color: themeBundle.textSecondary),
                    filled: true,
                    fillColor: themeBundle.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: themeBundle.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: themeBundle.textSecondary),
                    filled: true,
                    fillColor: themeBundle.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Rows: $rows', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w600)),
                    Row(
                      children: [2, 3, 4, 5].map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: ChoiceChip(
                            label: Text('$e'),
                            selected: rows == e,
                            onSelected: (_) => setState(() => rows = e),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Columns: $cols', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.w600)),
                    Row(
                      children: [2, 3, 4, 5].map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: ChoiceChip(
                            label: Text('$e'),
                            selected: cols == e,
                            onSelected: (_) => setState(() => cols = e),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (name.isNotEmpty) {
                  service.createProfile(name, description: desc, rows: rows, cols: cols);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Create Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
    });
  }

  void _exportProfile(BuildContext context, ProfileService service, DeckProfile profile) {
    final jsonStr = service.exportProfileToJson(profile.id);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile "${profile.name}" JSON copied to clipboard!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showImportDialog(BuildContext context, ProfileService service) {
    final themeBundle = AstraThemeBundle.of(context);
    final theme = Theme.of(context);
    final jsonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeBundle.cardBg,
        title: Text('Import Profile JSON', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: jsonCtrl,
          maxLines: 8,
          style: TextStyle(color: themeBundle.textPrimary, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Paste valid AstraDeck JSON schema here...',
            hintStyle: TextStyle(color: themeBundle.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: themeBundle.surfaceElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
            onPressed: () {
              final jsonText = jsonCtrl.text.trim();
              final ok = service.importProfileFromJson(jsonText);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Profile imported successfully!' : 'Invalid profile schema!'),
                  backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Import', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) => jsonCtrl.dispose());
  }

  void _confirmDelete(BuildContext context, ProfileService service, DeckProfile profile) {
    final themeBundle = AstraThemeBundle.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeBundle.cardBg,
        title: Text('Delete "${profile.name}"?', style: TextStyle(color: themeBundle.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete this profile and all configured buttons.',
          style: TextStyle(color: themeBundle.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              service.deleteProfile(profile.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DeckProfile profile;
  final bool isActive;
  final int index;
  final VoidCallback onSelect;
  final VoidCallback onSettings;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback? onDelete;

  const _ProfileCard({
    super.key,
    required this.profile,
    required this.isActive,
    required this.index,
    required this.onSelect,
    required this.onSettings,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);
    final accent = theme.colorScheme.primary;

    final firstPage = profile.pages.isNotEmpty ? profile.pages.first : null;
    final totalButtons = profile.pages.fold<int>(0, (sum, p) => sum + p.buttons.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: themeBundle.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? accent : themeBundle.borderColor,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? accent.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
            blurRadius: isActive ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Header icon, name, active badge, and drag handle + menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Icon or Thumbnail
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive ? accent.withValues(alpha: 0.2) : themeBundle.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? accent.withValues(alpha: 0.6) : themeBundle.borderColor,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isActive ? Icons.dashboard_rounded : Icons.grid_view_rounded,
                        color: isActive ? accent : themeBundle.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: themeBundle.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: accent.withValues(alpha: 0.5), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (profile.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              profile.description,
                              style: TextStyle(fontSize: 12, color: themeBundle.textSecondary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quick Settings Icon
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      color: themeBundle.textSecondary,
                      tooltip: 'Configure',
                      onPressed: onSettings,
                    ),

                    // Popup Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: themeBundle.textSecondary, size: 20),
                      color: themeBundle.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: themeBundle.borderColor),
                      ),
                      onSelected: (val) {
                        if (val == 'settings') onSettings();
                        if (val == 'dup') onDuplicate();
                        if (val == 'export') onExport();
                        if (val == 'del') onDelete?.call();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Settings & Triggers'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'dup',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Export JSON'),
                            ],
                          ),
                        ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'del',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('Delete', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Reorder handle
                    ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded, color: themeBundle.textSecondary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Middle section: Mini Grid Thumbnail Preview & Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mini thumbnail preview of first page
                    if (firstPage != null)
                      _buildMiniGrid(firstPage, profile.gridRows, profile.gridCols, themeBundle, accent),

                    const SizedBox(width: 14),

                    // Metadata chips
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildChip(
                            Icons.grid_on_rounded,
                            '${profile.gridRows}×${profile.gridCols}',
                            themeBundle,
                          ),
                          _buildChip(
                            Icons.layers_rounded,
                            '${profile.pages.length} ${profile.pages.length == 1 ? 'Page' : 'Pages'}',
                            themeBundle,
                          ),
                          _buildChip(
                            Icons.touch_app_rounded,
                            '$totalButtons Buttons',
                            themeBundle,
                          ),
                          if (profile.autoSwitchWindowTitle != null && profile.autoSwitchWindowTitle!.isNotEmpty)
                            _buildChip(
                              Icons.auto_awesome_rounded,
                              'Auto: ${profile.autoSwitchWindowTitle}',
                              themeBundle,
                              highlight: true,
                              accent: accent,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: themeBundle.borderColor.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 10),

                // Bottom row: Switch button or active indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isActive ? 'Currently controlling PC' : 'Tap card to switch',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? accent : themeBundle.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (!isActive)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeBundle.surfaceElevated,
                          foregroundColor: themeBundle.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: themeBundle.borderColor),
                          ),
                        ),
                        onPressed: onSelect,
                        child: const Text('Switch to Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text('Active on Deck', style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniGrid(
    DeckPage page,
    int rows,
    int cols,
    AstraThemeBundle bundle,
    Color accent,
  ) {
    // A tiny visual preview showing button layout
    const double gridSize = 56;
    return Container(
      width: gridSize,
      height: gridSize,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bundle.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bundle.borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: List.generate(rows, (r) {
          return Expanded(
            child: Row(
              children: List.generate(cols, (c) {
                final hasButton = page.buttons.any((b) => b.row == r && b.col == c);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: hasButton
                          ? (isActive ? accent.withValues(alpha: 0.8) : bundle.textSecondary.withValues(alpha: 0.5))
                          : bundle.cardBg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChip(
    IconData icon,
    String label,
    AstraThemeBundle bundle, {
    bool highlight = false,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? (accent?.withValues(alpha: 0.15) ?? bundle.surfaceElevated)
            : bundle.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? (accent?.withValues(alpha: 0.5) ?? bundle.borderColor)
              : bundle.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight ? accent : bundle.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? accent : bundle.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

