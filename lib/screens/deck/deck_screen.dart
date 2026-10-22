import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/deck_models.dart';
import '../../services/profile_service.dart';
import '../../services/settings_service.dart';
import '../../services/connection_service.dart';
import '../../services/deck_execution_service.dart';
import '../../services/live_state_service.dart';
import '../../theme/astradeck_theme.dart';
import '../../utils/icon_helper.dart';
import '../../widgets/button_editor_dialog.dart';
import '../../widgets/connect_pc_modal.dart';
import '../../widgets/profile_settings_sheet.dart';
import '../../widgets/folder_overlay_widget.dart';
import '../../widgets/swipe_page_switcher.dart';

class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final settingsService = context.watch<SettingsService>();
    final connectionService = context.watch<ConnectionService>();
    final executionService = context.watch<DeckExecutionService>();
    final liveStateService = context.watch<LiveStateService>();
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);

    final profile = profileService.currentProfile;
    final page = profileService.currentPage;
    final isEditMode = profileService.isEditMode;

    return Scaffold(
      backgroundColor: themeBundle.scaffoldBg,
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ProfileSettingsSheet.show(context, profile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.dashboard_customize_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: themeBundle.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, color: themeBundle.textSecondary, size: 18),
                        ],
                      ),
                      Text(
                        '${profile.gridRows}×${profile.gridCols} Grid • ${page.name}',
                        style: TextStyle(fontSize: 11, color: themeBundle.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                      color: themeBundle.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeBundle.borderColor),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            executionService.isSystemMuted ? Icons.volume_off : Icons.volume_up,
                            color: executionService.isSystemMuted ? Colors.redAccent : themeBundle.textSecondary,
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
                              inactiveColor: themeBundle.borderColor,
                              onChanged: (val) => executionService.setSystemVolume(val),
                            ),
                          ),
                        ),
                        Text(
                          '${executionService.systemVolume.round()}%',
                          style: TextStyle(fontSize: 10, color: themeBundle.textSecondary, fontWeight: FontWeight.bold),
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
                      color: themeBundle.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeBundle.borderColor),
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
                              inactiveColor: themeBundle.borderColor,
                              onChanged: (val) => executionService.setBrightness(val),
                            ),
                          ),
                        ),
                        Text(
                          '${executionService.screenBrightness.round()}%',
                          style: TextStyle(fontSize: 10, color: themeBundle.textSecondary, fontWeight: FontWeight.bold),
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
                color: themeBundle.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: executionService.isMicMuted
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : themeBundle.borderColor,
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
                        inactiveColor: themeBundle.borderColor,
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
                      color: executionService.isMicMuted ? Colors.redAccent : themeBundle.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Page Tab Bar
          if (profile.pages.length > 1 || isEditMode)
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: profile.pages.length + (isEditMode ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  if (idx == profile.pages.length) {
                    return ActionChip(
                      avatar: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                      label: const Text('Add Page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      backgroundColor: themeBundle.cardBg,
                      side: BorderSide(color: themeBundle.borderColor),
                      onPressed: () => _promptAddPage(context, profileService),
                    );
                  }
                  final isCurrent = idx == profileService.activePageIndex;
                  final pageItem = profile.pages[idx];
                  return GestureDetector(
                    onLongPress: () => _showPageOptions(context, profileService, idx, pageItem.name),
                    child: FilterChip(
                      selected: isCurrent,
                      label: Text(
                        pageItem.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? Colors.white : themeBundle.textSecondary,
                        ),
                      ),
                      selectedColor: settingsService.settings.accentColor,
                      backgroundColor: themeBundle.cardBg,
                      side: BorderSide(
                        color: isCurrent
                            ? settingsService.settings.accentColor
                            : themeBundle.borderColor,
                      ),
                      showCheckmark: false,
                      onSelected: (_) => profileService.setActivePage(idx),
                    ),
                  );
                },
              ),
            ),

          // Main Deck Button Grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(settingsService.settings.buttonSpacing),
              child: _buildGrid(context, profileService, settingsService, executionService, liveStateService),
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
    LiveStateService liveStateService,
  ) {
    final profile = profileService.currentProfile;
    final isEditMode = profileService.isEditMode;

    if (isEditMode) {
      return _buildSinglePageGrid(
        context,
        profileService.currentPage,
        profileService,
        settingsService,
        executionService,
        liveStateService,
        isEditMode: true,
      );
    }

    return SwipePageSwitcher(
      profile: profile,
      activePageIndex: profileService.activePageIndex,
      onPageChanged: (idx) => profileService.setActivePage(idx),
      pageBuilder: (context, page) => _buildSinglePageGrid(
        context,
        page,
        profileService,
        settingsService,
        executionService,
        liveStateService,
        isEditMode: false,
      ),
    );
  }

  Widget _buildSinglePageGrid(
    BuildContext context,
    DeckPage page,
    ProfileService profileService,
    SettingsService settingsService,
    DeckExecutionService executionService,
    LiveStateService liveStateService, {
    required bool isEditMode,
  }) {
    final profile = profileService.currentProfile;
    final spacing = settingsService.settings.buttonSpacing;
    final themeBundle = AstraThemeBundle.of(context);

    if (page.buttons.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeBundle.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeBundle.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 44,
                color: themeBundle.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No buttons on "${page.name}"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeBundle.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add shortcuts, hotkeys, media controls or app openers to build your deck.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: themeBundle.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsService.settings.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _addNewButton(context, profileService),
              ),
            ],
          ),
        ),
      );
    }

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
                liveStateService: liveStateService,
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
              liveStateService: liveStateService,
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
    LiveStateService? liveStateService,
  }) {
    final themeBundle = AstraThemeBundle.of(context);
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

    final isDefaultBg = button.backgroundColor == 0xFF1E293B;
    final isToggleActive = button.actionType == ActionType.toggleButton && button.toggleState;
    final baseBg = isDefaultBg ? themeBundle.cardBg : Color(button.backgroundColor);
    final bgColor = isToggleActive
        ? Color.alphaBlend(settingsService.settings.accentColor.withValues(alpha: 0.35), baseBg)
        : baseBg;
    final borderColor = isEditMode
        ? const Color(0xFFF59E0B)
        : (isToggleActive
            ? settingsService.settings.accentColor
            : (isDefaultBg ? themeBundle.borderColor : Colors.white12));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isEditMode) {
            _openButtonEditor(context, button, profileService);
          } else {
            _triggerAction(context, button, executionService, settingsService, liveStateService);
          }
        },
        onLongPress: isEditMode
            ? null
            : () {
                if (button.longPressActionType != null && button.longPressPayload != null) {
                  if (button.hapticFeedback && settingsService.settings.hapticFeedbackEnabled) {
                    HapticFeedback.mediumImpact();
                  }
                  final fakeButton = button.copyWith(
                    actionType: button.longPressActionType!,
                    actionPayload: button.longPressPayload!,
                  );
                  _triggerAction(context, fakeButton, executionService, settingsService, liveStateService);
                } else {
                  _openButtonEditor(context, button, profileService);
                }
              },
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor,
              width: isEditMode || isToggleActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isToggleActive
                    ? settingsService.settings.accentColor.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.25),
                blurRadius: isToggleActive ? 10 : 6,
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
                    () {
                      final liveValue = (button.liveStatePath != null && button.liveStatePath!.isNotEmpty)
                          ? liveStateService?.formatStateValue(button.liveStatePath)
                          : null;
                      final displaySubtitle = liveValue ?? button.subtitle;
                      if (displaySubtitle.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          displaySubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: liveValue != null
                                ? settingsService.settings.accentColor
                                : Color(button.textColor).withValues(alpha: 0.7),
                            fontWeight: liveValue != null ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }(),
                  ],
                ],
              ),
              if (button.actionType == ActionType.toggleButton && !isEditMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isToggleActive ? settingsService.settings.accentColor : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
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
    LiveStateService? liveStateService,
  ) {
    // Haptics feedback based on action type
    if (button.hapticFeedback && settingsService.settings.hapticFeedbackEnabled) {
      if (button.actionType == ActionType.toggleButton) {
        HapticFeedback.selectionClick();
      } else if (button.requiresConfirmation) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }

    // Folder popup overlay support
    if (button.actionType == ActionType.folderAction) {
      final rawList = button.actionPayload['buttons'];
      List<DeckButton> subButtons = [];
      if (rawList is List) {
        subButtons = rawList.map((e) => DeckButton.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      if (liveStateService != null) {
        FolderOverlayWidget.show(
          context,
          parentButton: button,
          buttons: subButtons,
          executionService: executionService,
          settingsService: settingsService,
          liveStateService: liveStateService,
        );
      }
      return;
    }

    final themeBundle = AstraThemeBundle.of(context);
    if (button.requiresConfirmation) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: themeBundle.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: themeBundle.borderColor),
          ),
          title: Text(
            'Execute ${button.title}?',
            style: TextStyle(color: themeBundle.textPrimary),
          ),
          content: Text(
            'Are you sure you want to trigger "${button.title}"?',
            style: TextStyle(color: themeBundle.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: settingsService.settings.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                executionService.executeButton(button, settingsService.settings);
              },
              child: const Text('Confirm'),
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

  void _showPageOptions(BuildContext context, ProfileService profileService, int pageIndex, String pageName) {
    final themeBundle = AstraThemeBundle.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: themeBundle.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: themeBundle.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.layers_rounded, color: themeBundle.textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Page: $pageName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeBundle.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: themeBundle.textPrimary),
                title: Text('Rename Page', style: TextStyle(color: themeBundle.textPrimary)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _promptRenamePage(context, profileService, pageIndex, pageName);
                },
              ),
              if (profileService.currentProfile.pages.length > 1)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Page', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _promptDeletePage(context, profileService, pageIndex, pageName);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptRenamePage(BuildContext context, ProfileService profileService, int pageIndex, String currentName) {
    final themeBundle = AstraThemeBundle.of(context);
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeBundle.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeBundle.borderColor),
        ),
        title: Text('Rename Page', style: TextStyle(color: themeBundle.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: themeBundle.textPrimary),
          decoration: InputDecoration(
            labelText: 'Page Name',
            labelStyle: TextStyle(color: themeBundle.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themeBundle.borderColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                profileService.renamePage(pageIndex, newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _promptDeletePage(BuildContext context, ProfileService profileService, int pageIndex, String pageName) {
    final themeBundle = AstraThemeBundle.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeBundle.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeBundle.borderColor),
        ),
        title: Text('Delete Page "$pageName"?', style: TextStyle(color: themeBundle.textPrimary)),
        content: Text(
          'All buttons on this page will be permanently removed.',
          style: TextStyle(color: themeBundle.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              profileService.deletePage(pageIndex);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _promptAddPage(BuildContext context, ProfileService profileService) {
    final themeBundle = AstraThemeBundle.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: themeBundle.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeBundle.borderColor),
        ),
        title: Text('Add Deck Page', style: TextStyle(color: themeBundle.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: themeBundle.textPrimary),
          decoration: InputDecoration(
            labelText: 'Page Name (e.g. Media, Dev)',
            labelStyle: TextStyle(color: themeBundle.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: themeBundle.borderColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: themeBundle.textSecondary)),
          ),
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
