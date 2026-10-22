import 'package:flutter/material.dart';
import '../models/deck_models.dart';
import '../theme/astradeck_theme.dart';
import '../utils/icon_helper.dart';

class ButtonEditorDialog extends StatefulWidget {
  final DeckButton button;
  final Function(DeckButton updated) onSave;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const ButtonEditorDialog({
    super.key,
    required this.button,
    required this.onSave,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<ButtonEditorDialog> createState() => _ButtonEditorDialogState();
}

class _ButtonEditorDialogState extends State<ButtonEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _payloadController;

  late String _iconName;
  late double _iconSize;
  late int _backgroundColor;
  late int _textColor;
  late ButtonShape _shape;
  late ActionType _actionType;
  late bool _requiresConfirmation;
  late bool _hapticFeedback;
  late bool _isEnabled;
  String? _liveStatePath;

  final List<int> _presetColors = [
    0xFF1E293B, // Slate
    0xFFDC2626, // Red
    0xFF2563EB, // Blue
    0xFF059669, // Green
    0xFFD97706, // Amber
    0xFF7C3AED, // Purple
    0xFFDB2777, // Pink
    0xFF0891B2, // Cyan
    0xFF000000, // Black
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.button.title);
    _subtitleController = TextEditingController(text: widget.button.subtitle);

    String defaultPayload = '';
    final p = widget.button.actionPayload;
    if (p.containsKey('url')) {
      defaultPayload = p['url'] ?? '';
    } else if (p.containsKey('app')) {
      defaultPayload = p['app'] ?? '';
    } else if (p.containsKey('definition')) {
      defaultPayload = p['definition'] ?? '';
    } else if (p.containsKey('command')) {
      defaultPayload = p['command'] ?? '';
    } else if (p.containsKey('keys')) {
      final keys = p['keys'];
      defaultPayload = keys is List ? keys.join('+') : keys.toString();
    } else if (p.containsKey('combo')) {
      defaultPayload = p['combo'] ?? '';
    } else if (p.containsKey('text')) {
      defaultPayload = p['text'] ?? '';
    }
    _payloadController = TextEditingController(text: defaultPayload);

    _iconName = widget.button.iconName;
    _iconSize = widget.button.iconSize;
    _backgroundColor = widget.button.backgroundColor;
    _textColor = widget.button.textColor;
    _shape = widget.button.shape;
    _actionType = widget.button.actionType;
    _requiresConfirmation = widget.button.requiresConfirmation;
    _hapticFeedback = widget.button.hapticFeedback;
    _isEnabled = widget.button.isEnabled;
    _liveStatePath = widget.button.liveStatePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  void _save() {
    Map<String, dynamic> payload = Map<String, dynamic>.from(widget.button.actionPayload);
    final text = _payloadController.text.trim();

    if (_actionType == ActionType.openWebsite) {
      payload['url'] = text;
    } else if (_actionType == ActionType.launchApp) {
      payload['app'] = text;
    } else if (_actionType == ActionType.injectHotkey) {
      final cleanCombo = text.replaceAll(' ', '');
      payload['combo'] = cleanCombo;
      payload['keys'] = cleanCombo.split('+').where((k) => k.isNotEmpty).toList();
    } else if (_actionType == ActionType.pasteText) {
      payload['text'] = _payloadController.text;
    } else if (_actionType == ActionType.mediaControl) {
      payload['command'] = text.isEmpty ? 'play_pause' : text;
    } else if (_actionType == ActionType.spotifyAction) {
      payload['command'] = text.isEmpty ? 'play_pause' : text;
    } else if (_actionType == ActionType.discordAction) {
      payload['command'] = text.isEmpty ? 'toggle_mute' : text;
    } else if (_actionType == ActionType.dynamicFunction) {
      payload['definition'] = text;
      payload['command'] = text;
      if (widget.button.actionPayload.containsKey('function_id')) {
        payload['function_id'] = widget.button.actionPayload['function_id'];
      }
    } else if (_actionType == ActionType.obsAction) {
      payload['command'] = text.isNotEmpty ? text : 'toggle_record';
    } else if (_actionType == ActionType.setVolume) {
      payload['step'] = double.tryParse(text) ?? 5.0;
    } else if (_actionType == ActionType.setBrightness) {
      payload['step'] = double.tryParse(text) ?? 10.0;
    }

    final updated = widget.button.copyWith(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      iconName: _iconName,
      iconSize: _iconSize,
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      shape: _shape,
      actionType: _actionType,
      actionPayload: payload,
      requiresConfirmation: _requiresConfirmation,
      hapticFeedback: _hapticFeedback,
      isEnabled: _isEnabled,
      liveStatePath: _liveStatePath,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Text(
                    'Configure Action Button',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),

            // Form Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Live Preview Card
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(_backgroundColor),
                        borderRadius: _shape == ButtonShape.circle
                            ? BorderRadius.circular(50)
                            : BorderRadius.circular(_shape == ButtonShape.square ? 4 : 16),
                        border: Border.all(color: Colors.white24, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(IconHelper.getIcon(_iconName), color: Color(_textColor), size: _iconSize),
                          const SizedBox(height: 4),
                          Text(
                            _titleController.text.isEmpty ? 'Title' : _titleController.text,
                            style: TextStyle(
                              color: Color(_textColor),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle Fields
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Button Label / Title',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subtitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Subtitle (Optional)',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Live Data Feed Dropdown
                  DropdownButtonFormField<String?>(
                    initialValue: _liveStatePath,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Live Dynamic Value (Feed)',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                      helperText: 'Dynamically shows PC metrics or current track title',
                      helperStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('None (Static Subtitle)'),
                      ),
                      DropdownMenuItem(
                        value: 'system.cpu_percent',
                        child: Text('💻 CPU Usage %'),
                      ),
                      DropdownMenuItem(
                        value: 'system.ram_percent',
                        child: Text('🧠 RAM Usage %'),
                      ),
                      DropdownMenuItem(
                        value: 'media.title',
                        child: Text('🎵 Media Track Title'),
                      ),
                      DropdownMenuItem(
                        value: 'media.artist',
                        child: Text('🎤 Media Artist'),
                      ),
                      DropdownMenuItem(
                        value: 'spotify.track',
                        child: Text('🟢 Spotify Track'),
                      ),
                      DropdownMenuItem(
                        value: 'window.title',
                        child: Text('🪟 Active Window Title'),
                      ),
                      DropdownMenuItem(
                        value: 'obs.recording',
                        child: Text('🔴 OBS Recording Status'),
                      ),
                      DropdownMenuItem(
                        value: 'obs.streaming',
                        child: Text('📡 OBS Streaming Status'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _liveStatePath = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Action Type Dropdown
                  DropdownButtonFormField<ActionType>(
                    initialValue: _actionType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Action Type',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                    ),
                    items: ActionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _actionType = val;
                          if (_actionType == ActionType.openWebsite && _payloadController.text.isEmpty) {
                            _payloadController.text = 'https://google.com';
                          } else if (_actionType == ActionType.launchApp && _payloadController.text.isEmpty) {
                            _payloadController.text = 'Chrome';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Action Payload Input
                  TextField(
                    controller: _payloadController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _getPayloadLabel(),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: const OutlineInputBorder(),
                      helperText: _getPayloadHelper(),
                      helperMaxLines: 2,
                      helperStyle: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  if (_actionType == ActionType.dynamicFunction) ...[
                    const SizedBox(height: 8),
                    const Text('Quick Desired Actions:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Lock Screen', 'lock screen', 'lock'),
                        _buildQuickActionChip('Window Screenshot', 'take screenshot of active window', 'camera_alt'),
                        _buildQuickActionChip('Toggle Night Light', 'toggle dark mode night light', 'nightlight'),
                        _buildQuickActionChip('Switch Audio', 'switch audio output', 'headset'),
                        _buildQuickActionChip('Open Terminal', 'open terminal', 'terminal'),
                        _buildQuickActionChip('Empty Trash', 'empty trash and clean cache', 'delete'),
                      ],
                    ),
                  ] else if (_actionType == ActionType.injectHotkey) ...[
                    const SizedBox(height: 8),
                    const Text('Quick Shortcuts:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Copy', 'ctrl+c', 'content_copy'),
                        _buildQuickActionChip('Paste', 'ctrl+v', 'content_paste'),
                        _buildQuickActionChip('Undo', 'ctrl+z', 'undo'),
                        _buildQuickActionChip('Save', 'ctrl+s', 'save'),
                        _buildQuickActionChip('Task Mgr', 'ctrl+shift+escape', 'tune'),
                        _buildQuickActionChip('Alt+Tab', 'alt+tab', 'swap_horiz'),
                        _buildQuickActionChip('Show Desktop', 'super+d', 'desktop_windows'),
                        _buildQuickActionChip('Fullscreen', 'f11', 'fullscreen'),
                      ],
                    ),
                  ] else if (_actionType == ActionType.mediaControl) ...[
                    const SizedBox(height: 8),
                    const Text('Playback Commands:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Play / Pause', 'play_pause', 'play_arrow'),
                        _buildQuickActionChip('Next Track', 'next', 'skip_next'),
                        _buildQuickActionChip('Prev Track', 'previous', 'skip_previous'),
                        _buildQuickActionChip('Stop', 'stop', 'stop'),
                      ],
                    ),
                  ] else if (_actionType == ActionType.spotifyAction) ...[
                    const SizedBox(height: 8),
                    const Text('Spotify Commands (Free & Premium):', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Play / Pause', 'play_pause', 'music_note'),
                        _buildQuickActionChip('Next Track', 'next', 'skip_next'),
                        _buildQuickActionChip('Prev Track', 'previous', 'skip_previous'),
                      ],
                    ),
                  ] else if (_actionType == ActionType.discordAction) ...[
                    const SizedBox(height: 8),
                    const Text('Discord Commands:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Mute Mic', 'toggle_mute', 'mic_off'),
                        _buildQuickActionChip('Deafen', 'toggle_deafen', 'headset_off'),
                      ],
                    ),
                  ] else if (_actionType == ActionType.obsAction) ...[
                    const SizedBox(height: 8),
                    const Text('OBS Studio Commands:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickActionChip('Toggle Record', 'toggle_recording', 'videocam'),
                        _buildQuickActionChip('Toggle Stream', 'toggle_streaming', 'live_tv'),
                        _buildQuickActionChip('Virtual Cam', 'toggle_virtual_cam', 'switch_video'),
                        _buildQuickActionChip('Toggle Mic', 'toggle_mute', 'mic'),
                        _buildQuickActionChip('Save Replay', 'save_replay_buffer', 'history'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Icon Picker
                  const Text('Select Icon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: IconHelper.icons.entries.map((entry) {
                        final isSel = entry.key == _iconName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _iconName = entry.key),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 50,
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSel ? Colors.white : Colors.white24),
                              ),
                              child: Icon(entry.value, color: Colors.white, size: 24),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Background Color
                  const Text('Button Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((colorHex) {
                      final isSel = _backgroundColor == colorHex;
                      return InkWell(
                        onTap: () => setState(() => _backgroundColor = colorHex),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Button Shape Selector
                  const Text('Button Shape', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<ButtonShape>(
                    segments: const [
                      ButtonSegment(value: ButtonShape.roundedRect, label: Text('Rounded')),
                      ButtonSegment(value: ButtonShape.squircle, label: Text('Smooth')),
                      ButtonSegment(value: ButtonShape.square, label: Text('Square')),
                      ButtonSegment(value: ButtonShape.circle, label: Text('Circle')),
                    ],
                    selected: {_shape},
                    onSelectionChanged: (val) => setState(() => _shape = val.first),
                  ),
                  const SizedBox(height: 16),

                  // Options
                  SwitchListTile(
                    title: const Text('Require Confirmation', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Prevent accidental triggers', style: TextStyle(color: Color(0xFF94A3B8))),
                    value: _requiresConfirmation,
                    onChanged: (val) => setState(() => _requiresConfirmation = val),
                    activeThumbColor: const Color(0xFF6366F1),
                  ),
                  SwitchListTile(
                    title: const Text('Haptic Vibration', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Tactile tap feedback', style: TextStyle(color: Color(0xFF94A3B8))),
                    value: _hapticFeedback,
                    onChanged: (val) => setState(() => _hapticFeedback = val),
                    activeThumbColor: const Color(0xFF6366F1),
                  ),
                  SwitchListTile(
                    title: const Text('Enable Button', style: TextStyle(color: Colors.white)),
                    value: _isEnabled,
                    onChanged: (val) => setState(() => _isEnabled = val),
                    activeThumbColor: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),

            // Footer Actions
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blueAccent),
                    tooltip: 'Duplicate Button',
                    onPressed: () {
                      widget.onDuplicate();
                      Navigator.of(context).pop();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Button',
                    onPressed: () {
                      widget.onDelete();
                      Navigator.of(context).pop();
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, String actionDef, String icon) {
    final themeBundle = AstraThemeBundle.of(context);
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: themeBundle.textPrimary)),
      backgroundColor: themeBundle.surfaceElevated,
      side: BorderSide(color: themeBundle.borderColor),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () {
        setState(() {
          _payloadController.text = actionDef;
          if (_titleController.text.isEmpty || _titleController.text == 'Action Button' || _titleController.text == 'New Action') {
            _titleController.text = label;
          }
          _iconName = icon;
        });
      },
    );
  }

  String _getPayloadLabel() {
    switch (_actionType) {
      case ActionType.openWebsite:
        return 'Target URL (https://...)';
      case ActionType.launchApp:
        return 'Desktop App Name (e.g. OBS Studio, Discord, Chrome)';
      case ActionType.dynamicFunction:
        return 'Desired Action / Intent (e.g. "Lock screen", command)';
      case ActionType.obsAction:
        return 'OBS Command (toggle_stream, switch_scene)';
      case ActionType.setVolume:
        return 'Volume Delta (+/- 5, 10)';
      case ActionType.setBrightness:
        return 'Brightness Delta (+/- 10)';
      case ActionType.injectHotkey:
        return 'Hotkey Combo (e.g. ctrl+shift+z, alt+tab, f11)';
      case ActionType.pasteText:
        return 'Text to Paste / Type';
      case ActionType.mediaControl:
        return 'Media Command (play_pause, next, previous, stop)';
      case ActionType.spotifyAction:
        return 'Spotify Command (play_pause, next, previous)';
      case ActionType.discordAction:
        return 'Discord Action (toggle_mute, toggle_deafen)';
      case ActionType.toggleButton:
        return 'Toggle Configuration (JSON or state identifier)';
      case ActionType.folderAction:
        return 'Folder / Target Page Name';
      default:
        return 'Action Parameter';
    }
  }

  String _getPayloadHelper() {
    switch (_actionType) {
      case ActionType.launchApp:
        return 'Opens native app (if open, focuses); opens in browser if not installed.';
      case ActionType.openWebsite:
        return 'Opens in default browser (reopens every time clicked).';
      case ActionType.dynamicFunction:
        return 'AstraDeck dynamically creates and executes a function on PC for this action.';
      case ActionType.injectHotkey:
        return 'Simulates physical key combination on PC (works across Linux X11/Wayland, macOS, Windows).';
      case ActionType.pasteText:
        return 'Types this text directly into whatever window is focused on your desktop.';
      case ActionType.mediaControl:
        return 'Native OS media control. Controls Spotify, browsers, VLC with zero setup or API keys.';
      case ActionType.spotifyAction:
        return 'OS-level Spotify integration via MPRIS / AppleScript. Works with Free or Premium without tokens.';
      case ActionType.discordAction:
        return 'Triggers Discord mute or deafen shortcut.';
      case ActionType.toggleButton:
        return 'Switches between two states on every tap with real-time visual indicator.';
      case ActionType.obsAction:
        return 'Controls OBS Studio via WebSocket (recording, streaming, scene switching, virtual camera).';
      case ActionType.folderAction:
        return 'Switches to the designated page or folder.';
      default:
        return 'Validated execution parameter';
    }
  }
}
