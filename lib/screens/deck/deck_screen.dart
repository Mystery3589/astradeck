import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/deck_models.dart';
import '../../services/profile_service.dart';
import '../../services/settings_service.dart';
import '../../services/connection_service.dart';
import '../../services/deck_execution_service.dart';
import '../../utils/icon_helper.dart';
import '../../widgets/button_editor_dialog.dart';
import '../../widgets/connect_pc_modal.dart';

class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final settingsService = context.watch<SettingsService>();
    final connectionService = context.watch<ConnectionService>();
    final executionService = context.watch<DeckExecutionService>();

    final profile = profileService.currentProfile;
    final page = profileService.currentPage;
    final isEditMode = profileService.isEditMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: settingsService.settings.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.dashboard_customize, color: settingsService.settings.accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('AstraDeck', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    '${profile.name} • ${page.name}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Connection pill indicator
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              if (!connectionService.isConnected) {
                final ok = await connectionService.autoConnect();
                if (!context.mounted) return;
                if (!ok) {
                  ConnectPcModal.show(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Connected to ${connectionService.activeDevice?.name ?? "PC"}!',
                      ),
                    ),
                  );
                }
              } else {
                final dev = connectionService.activeDevice;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connected to ${dev?.name ?? "PC"} (${dev?.ipAddress}:${dev?.port}) • ${dev?.latencyMs ?? 0}ms latency',
                    ),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: connectionService.isConnected
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : connectionService.isConnecting
                        ? Colors.amber.withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: connectionService.isConnected
                      ? const Color(0xFF10B981)
                      : connectionService.isConnecting
                          ? Colors.amber
                          : const Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor: connectionService.isConnected
                        ? const Color(0xFF10B981)
                        : connectionService.isConnecting
                            ? Colors.amber
                            : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connectionService.isConnected
                        ? '${connectionService.activeDevice?.latencyMs ?? 0}ms'
                        : connectionService.isConnecting
                            ? 'Connecting...'
                            : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: connectionService.isConnected
                          ? const Color(0xFF10B981)
                          : connectionService.isConnecting
                              ? Colors.amber
                              : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Edit Mode Switch
          IconButton(
            icon: Icon(
              isEditMode ? Icons.check_circle : Icons.tune,
              color: isEditMode ? const Color(0xFF10B981) : Colors.white70,
            ),
            tooltip: isEditMode ? 'Finish Editing' : 'Customize Layout',
            onPressed: () => profileService.toggleEditMode(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Edit Mode Banner
          if (isEditMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'EDIT MODE: Tap a button to configure or drag to reorder.',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (profileService.canUndo)
                    IconButton(
                      icon: const Icon(Icons.undo, size: 18, color: Colors.white),
                      tooltip: 'Undo',
                      onPressed: () => profileService.undo(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    tooltip: 'Add Button',
                    onPressed: () => _addNewButton(context, profileService),
                  ),
                ],
              ),
            ),

          // Waiting for PC Companion / Auto-Reconnect Banner
          if (connectionService.isWaitingForHost)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Waiting for PC companion to start...',
                      style: TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ConnectPcModal.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Setup Guide',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Volume & Brightness Control Sliders
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            executionService.isSystemMuted ? Icons.volume_off : Icons.volume_up,
                            color: executionService.isSystemMuted ? Colors.redAccent : Colors.white70,
                            size: 16,
                          ),
                          onPressed: () => executionService.toggleSystemMute(),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                            ),
                            child: Slider(
                              value: executionService.systemVolume,
                              min: 0,
                              max: 100,
                              activeColor: settingsService.settings.accentColor,
                              inactiveColor: Colors.white24,
                              onChanged: (val) => executionService.setSystemVolume(val),
                            ),
                          ),
                        ),
                        Text(
                          '${executionService.systemVolume.round()}%',
                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Brightness slider
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.brightness_medium, color: Colors.amber, size: 16),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                            ),
                            child: Slider(
                              value: executionService.screenBrightness,
                              min: 0,
                              max: 100,
                              activeColor: Colors.amber,
                              inactiveColor: Colors.white24,
                              onChanged: (val) => executionService.setBrightness(val),
                            ),
                          ),
                        ),
                        Text(
                          '${executionService.screenBrightness.round()}%',
                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mic Controls Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: executionService.isMicMuted
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      executionService.isMicMuted ? Icons.mic_off : Icons.mic,
                      color: executionService.isMicMuted ? Colors.redAccent : const Color(0xFF34D399),
                      size: 16,
                    ),
                    onPressed: () => executionService.toggleMicMute(),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      ),
                      child: Slider(
                        value: executionService.micVolume,
                        min: 0,
                        max: 100,
                        activeColor: executionService.isMicMuted
                            ? Colors.redAccent
                            : const Color(0xFF34D399),
                        inactiveColor: Colors.white24,
                        onChanged: executionService.isMicMuted
                            ? null
                            : (val) => executionService.setMicVolume(val),
                      ),
                    ),
                  ),
                  Text(
                    executionService.isMicMuted
                        ? 'MUTED'
                        : '${executionService.micVolume.round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: executionService.isMicMuted ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Deck Button Grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(settingsService.settings.buttonSpacing),
              child: _buildGrid(context, profileService, settingsService, executionService),
            ),
          ),

          // Page Switcher Navigation Bar
          if (profile.pages.length > 1 || isEditMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(profile.pages.length, (idx) {
                    final isCurrent = idx == profileService.activePageIndex;
                    return InkWell(
                      onTap: () => profileService.setActivePage(idx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? settingsService.settings.accentColor
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.pages[idx].name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (isEditMode)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                      tooltip: 'Add Deck Page',
                      onPressed: () => _promptAddPage(context, profileService),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    ProfileService profileService,
    SettingsService settingsService,
    DeckExecutionService executionService,
  ) {
    final page = profileService.currentPage;
    final profile = profileService.currentProfile;
    final isEditMode = profileService.isEditMode;
    final spacing = settingsService.settings.buttonSpacing;

    if (isEditMode) {
      // Reorderable wrap / grid during edit mode
      return ReorderableListView(
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.zero,
        onReorderItem: (oldIndex, newIndex) => profileService.reorderButtons(oldIndex, newIndex),
        children: [
          for (int i = 0; i < page.buttons.length; i++)
            Container(
              key: ValueKey(page.buttons[i].id),
              margin: EdgeInsets.only(bottom: spacing),
              child: _buildDeckButton(
                context,
                page.buttons[i],
                profileService,
                settingsService,
                executionService,
                isEditMode: true,
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = profile.gridCols;
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.0,
          ),
          itemCount: page.buttons.length,
          itemBuilder: (context, index) {
            final button = page.buttons[index];
            return _buildDeckButton(
              context,
              button,
              profileService,
              settingsService,
              executionService,
              isEditMode: false,
            );
          },
        );
      },
    );
  }

  Widget _buildDeckButton(
    BuildContext context,
    DeckButton button,
    ProfileService profileService,
    SettingsService settingsService,
    DeckExecutionService executionService, {
    required bool isEditMode,
  }) {
    final radius = settingsService.settings.buttonCornerRadius;
    final showLabels = settingsService.settings.showButtonLabels;
    final iconOnly = settingsService.settings.iconOnlyMode;

    BorderRadius borderRadius;
    switch (button.shape) {
      case ButtonShape.circle:
        borderRadius = BorderRadius.circular(100);
        break;
      case ButtonShape.square:
        borderRadius = BorderRadius.circular(4);
        break;
      case ButtonShape.squircle:
      case ButtonShape.roundedRect:
        borderRadius = BorderRadius.circular(radius);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isEditMode) {
            _openButtonEditor(context, button, profileService);
          } else {
            _triggerAction(context, button, executionService, settingsService);
          }
        },
        onLongPress: isEditMode
            ? null
            : () {
                _openButtonEditor(context, button, profileService);
              },
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: Color(button.backgroundColor),
            borderRadius: borderRadius,
            border: Border.all(
              color: isEditMode ? const Color(0xFFF59E0B) : Colors.white12,
              width: isEditMode ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconHelper.getIcon(button.iconName),
                    color: Color(button.textColor),
                    size: button.iconSize,
                  ),
                  if (showLabels && !iconOnly) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        button.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(button.textColor),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (button.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          button.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(button.textColor).withValues(alpha: 0.7),
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ],
              ),
              if (isEditMode)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(0xFFF59E0B),
                    child: Icon(Icons.edit, size: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerAction(
    BuildContext context,
    DeckButton button,
    DeckExecutionService executionService,
    SettingsService settingsService,
  ) {
    if (button.requiresConfirmation) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Execute ${button.title}?'),
          content: Text('Are you sure you want to trigger "${button.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () {
                Navigator.of(ctx).pop();
                executionService.executeButton(button, settingsService.settings);
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      executionService.executeButton(button, settingsService.settings);
    }
  }

  void _openButtonEditor(BuildContext context, DeckButton button, ProfileService profileService) {
    showDialog(
      context: context,
      builder: (ctx) => ButtonEditorDialog(
        button: button,
        onSave: (updated) => profileService.saveButton(updated),
        onDelete: () => profileService.deleteButton(button.id),
        onDuplicate: () => profileService.duplicateButton(button),
      ),
    );
  }

  void _addNewButton(BuildContext context, ProfileService profileService) {
    final newBtn = DeckButton(
      id: const Uuid().v4(),
      title: 'New Action',
      iconName: 'play_arrow',
      row: 0,
      col: 0,
      actionType: ActionType.openWebsite,
      actionPayload: {'url': 'https://google.com'},
    );
    _openButtonEditor(context, newBtn, profileService);
  }

  void _promptAddPage(BuildContext context, ProfileService profileService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Deck Page'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Page Name (e.g. Controls 2)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final pageName = controller.text.trim();
              Navigator.of(ctx).pop();
              profileService.addPage(pageName);
            },
            child: const Text('Add Page'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
