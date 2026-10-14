import 'package:flutter/material.dart';
import '../models/deck_models.dart';
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
    if (widget.button.actionPayload.containsKey('url')) {
      defaultPayload = widget.button.actionPayload['url'];
    } else if (widget.button.actionPayload.containsKey('app')) {
      defaultPayload = widget.button.actionPayload['app'];
    } else if (widget.button.actionPayload.containsKey('command')) {
      defaultPayload = widget.button.actionPayload['command'];
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  void _save() {
    Map<String, dynamic> payload = {};
    if (_actionType == ActionType.openWebsite) {
      payload['url'] = _payloadController.text.trim();
    } else if (_actionType == ActionType.launchApp) {
      payload['app'] = _payloadController.text.trim();
    } else if (_actionType == ActionType.obsAction) {
      payload['command'] = _payloadController.text.trim().isNotEmpty
          ? _payloadController.text.trim()
          : 'toggle_record';
    } else if (_actionType == ActionType.setVolume) {
      payload['step'] = double.tryParse(_payloadController.text) ?? 5.0;
    } else if (_actionType == ActionType.setBrightness) {
      payload['step'] = double.tryParse(_payloadController.text) ?? 10.0;
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
                      helperText: 'Validated allowlisted execution target',
                      helperStyle: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
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

  String _getPayloadLabel() {
    switch (_actionType) {
      case ActionType.openWebsite:
        return 'Target URL (https://...)';
      case ActionType.launchApp:
        return 'Desktop App Name (e.g. Chrome, Spotify)';
      case ActionType.obsAction:
        return 'OBS Command (toggle_stream, switch_scene)';
      case ActionType.setVolume:
        return 'Volume Delta (+/- 5, 10)';
      case ActionType.setBrightness:
        return 'Brightness Delta (+/- 10)';
      default:
        return 'Action Parameter';
    }
  }
}
