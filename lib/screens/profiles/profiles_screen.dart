import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/deck_models.dart';
import '../../services/profile_service.dart';
import '../../services/settings_service.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final settingsService = context.watch<SettingsService>();
    final profiles = profileService.profiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles & Layouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Profile (JSON)',
            onPressed: () => _showImportDialog(context, profileService),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Profile',
            onPressed: () => _showCreateProfileDialog(context, profileService),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final isActive = profile.id == profileService.activeProfileId;

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isActive
                    ? settingsService.settings.accentColor
                    : const Color(0xFF334155),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? settingsService.settings.accentColor.withValues(alpha: 0.2)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.grid_view,
                          color: isActive
                              ? settingsService.settings.accentColor
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: settingsService.settings.accentColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: settingsService.settings.accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (profile.description.isNotEmpty)
                              Text(
                                profile.description,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white70),
                        color: const Color(0xFF1E293B),
                        onSelected: (val) {
                          if (val == 'dup') {
                            profileService.duplicateProfile(profile.id);
                          } else if (val == 'rename') {
                            _showRenameDialog(context, profileService, profile);
                          } else if (val == 'export') {
                            _exportProfile(context, profileService, profile);
                          } else if (val == 'del') {
                            _confirmDelete(context, profileService, profile);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                          const PopupMenuItem(value: 'rename', child: Text('Rename & Details')),
                          const PopupMenuItem(value: 'export', child: Text('Export JSON')),
                          if (profiles.length > 1)
                            const PopupMenuItem(
                              value: 'del',
                              child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Grid: ${profile.gridRows}×${profile.gridCols} • ${profile.pages.length} Pages • ${profile.pages.fold<int>(0, (sum, p) => sum + p.buttons.length)} Buttons',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const Spacer(),
                      if (!isActive)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: () => profileService.setActiveProfile(profile.id),
                          child: const Text('Switch Profile'),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: settingsService.settings.accentColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            // Already active
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('In Use'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context, ProfileService service) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int rows = 3;
    int cols = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Create Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Profile Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grid Rows:', style: TextStyle(color: Colors.white)),
                  DropdownButton<int>(
                    value: rows,
                    dropdownColor: const Color(0xFF0F172A),
                    items: [2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) => setState(() => rows = v!),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grid Columns:', style: TextStyle(color: Colors.white)),
                  DropdownButton<int>(
                    value: cols,
                    dropdownColor: const Color(0xFF0F172A),
                    items: [2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) => setState(() => cols = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  service.createProfile(nameCtrl.text.trim(), description: descCtrl.text.trim(), rows: rows, cols: cols);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ProfileService service, DeckProfile profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final descCtrl = TextEditingController(text: profile.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Profile Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              service.renameProfile(profile.id, nameCtrl.text.trim(), descCtrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportProfile(BuildContext context, ProfileService service, DeckProfile profile) {
    final jsonStr = service.exportProfileToJson(profile.id);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile "${profile.name}" JSON copied to clipboard! (Safe export without credentials)'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _showImportDialog(BuildContext context, ProfileService service) {
    final jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Import Profile JSON'),
        content: TextField(
          controller: jsonCtrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste valid AstraDeck JSON schema here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final ok = service.importProfileFromJson(jsonCtrl.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Profile imported successfully!' : 'Invalid profile schema or rejected unsafe action!'),
                  backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProfileService service, DeckProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Delete "${profile.name}"?'),
        content: const Text('This will permanently delete this profile and all configured buttons.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              service.deleteProfile(profile.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
