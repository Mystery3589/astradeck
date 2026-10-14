import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/connection_service.dart';
import '../../services/settings_service.dart';
import '../../services/profile_service.dart';
import '../../services/deck_execution_service.dart';
import '../../services/obs_service.dart';

class SettingsDashboardScreen extends StatefulWidget {
  const SettingsDashboardScreen({super.key});

  @override
  State<SettingsDashboardScreen> createState() => _SettingsDashboardScreenState();
}

class _SettingsDashboardScreenState extends State<SettingsDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final connectionService = context.watch<ConnectionService>();
    final profileService = context.watch<ProfileService>();
    final obsService = context.watch<ObsService>();
    final executionService = context.watch<DeckExecutionService>();

    final categories = [
      _SettingCategory(
        id: 'conn',
        title: 'Connection & Devices',
        subtitle: 'Auto-discovery, pairing PINs, Wi-Fi, Bluetooth & USB tethering',
        icon: Icons.wifi_tethering,
        color: Colors.blueAccent,
        onTap: () => _openCategory(context, _buildConnectionSettings(context, connectionService, settingsService)),
      ),
      _SettingCategory(
        id: 'desktop',
        title: 'Desktop Configuration',
        subtitle: 'Host PC info, agent version, target apps, capability audits & logs',
        icon: Icons.computer,
        color: Colors.tealAccent,
        onTap: () => _openCategory(context, _buildDesktopConfiguration(context, connectionService, executionService)),
      ),
      _SettingCategory(
        id: 'appearance',
        title: 'Deck Appearance',
        subtitle: 'Dark/light theme, accent palette, button shapes, radius, animations',
        icon: Icons.palette,
        color: Colors.purpleAccent,
        onTap: () => _openCategory(context, _buildAppearanceSettings(context, settingsService)),
      ),
      _SettingCategory(
        id: 'layout',
        title: 'Layout & Button Editor',
        subtitle: 'Grid rows/cols presets (2x3, 3x3, 4x4, 5x3), margins & padding',
        icon: Icons.grid_on,
        color: Colors.orangeAccent,
        onTap: () => _openCategory(context, _buildLayoutEditorSettings(context, profileService)),
      ),
      _SettingCategory(
        id: 'audio_bright',
        title: 'Audio & Brightness',
        subtitle: 'Output device selection, step delta sizes, hardware vs software dimming',
        icon: Icons.volume_up,
        color: Colors.pinkAccent,
        onTap: () => _openCategory(context, _buildAudioBrightnessSettings(context, settingsService, executionService)),
      ),
      _SettingCategory(
        id: 'obs',
        title: 'OBS Studio',
        subtitle: 'WebSocket v5 host, port, safe credentials, scenes & mic sources',
        icon: Icons.videocam,
        color: Colors.redAccent,
        onTap: () => _openCategory(context, _buildObsSettings(context, obsService)),
      ),
      _SettingCategory(
        id: 'profiles_backup',
        title: 'Profiles & Backup',
        subtitle: 'Import/export JSON schemas, switch defaults, restore presets',
        icon: Icons.backup,
        color: Colors.indigoAccent,
        onTap: () => _openCategory(context, _buildProfilesBackupSettings(context, profileService)),
      ),
      _SettingCategory(
        id: 'security',
        title: 'Security & Privacy',
        subtitle: 'Trusted PC list, revoke tokens, sanitization, clear local storage',
        icon: Icons.shield,
        color: Colors.greenAccent,
        onTap: () => _openCategory(context, _buildSecuritySettings(context, settingsService, connectionService)),
      ),
      _SettingCategory(
        id: 'notifications',
        title: 'Notifications',
        subtitle: 'Disconnect alerts, profile change feedback, system toasts',
        icon: Icons.notifications_active,
        color: Colors.amberAccent,
        onTap: () => _openCategory(context, _buildNotificationSettings(context, settingsService)),
      ),
      _SettingCategory(
        id: 'advanced',
        title: 'Advanced',
        subtitle: 'Socket timeout, keep-alive heartbeat interval, low-overhead mode',
        icon: Icons.build_circle,
        color: Colors.cyanAccent,
        onTap: () => _openCategory(context, _buildAdvancedSettings(context, settingsService)),
      ),
      _SettingCategory(
        id: 'about',
        title: 'About & Diagnostics',
        subtitle: 'AstraDeck v2.4.0, latency benchmark, hardware tests & export report',
        icon: Icons.info,
        color: Colors.deepPurpleAccent,
        onTap: () => _openCategory(context, _buildDiagnosticsSettings(context, connectionService, executionService, obsService)),
      ),
    ];

    final filtered = categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
      ),
      body: Column(
        children: [
          // Header Status Badge: Version + Active Device + Active Profile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AstraDeck v2.4.0 (Enterprise Deck)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PC: ${connectionService.activeDevice?.name ?? "Disconnected"} • Profile: ${profileService.currentProfile.name}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: connectionService.isConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    connectionService.isConnected ? 'LINKED' : 'UNLINKED',
                    style: TextStyle(
                      color: connectionService.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search preferences (e.g. OBS, audio, wifi, theme)...',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Searchable Categories List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final cat = filtered[idx];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cat.color.withValues(alpha: 0.15),
                      child: Icon(cat.icon, color: cat.color),
                    ),
                    title: Text(cat.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(cat.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: cat.onTap,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // --- Sub-Screens for All 11 Categories ---

  // 1. Connection & Devices
  Widget _buildConnectionSettings(BuildContext context, ConnectionService conn, SettingsService settings) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Auto-discover Desktop Agents on Wi-Fi'),
            subtitle: const Text('Broadcast UDP queries on local subnet upon app launch'),
            value: settings.settings.autoDiscoverWifi,
            onChanged: (v) => settings.updateSettings(autoDiscoverWifi: v),
          ),
          SwitchListTile(
            title: const Text('Auto-reconnect to Last Preferred Device'),
            subtitle: const Text('Instantly restore handshake when connection drops'),
            value: settings.settings.autoReconnectLastDevice,
            onChanged: (v) => settings.updateSettings(autoReconnectLastDevice: v),
          ),
          ListTile(
            title: const Text('Handshake Timeout'),
            subtitle: Text('${settings.settings.connectionTimeoutSeconds} seconds'),
            trailing: DropdownButton<int>(
              value: settings.settings.connectionTimeoutSeconds,
              dropdownColor: const Color(0xFF1E293B),
              items: [3, 5, 10, 15].map((e) => DropdownMenuItem(value: e, child: Text('$e s'))).toList(),
              onChanged: (v) => settings.updateSettings(connectionTimeoutSeconds: v!),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Desktop Configuration
  Widget _buildDesktopConfiguration(BuildContext context, ConnectionService conn, DeckExecutionService exec) {
    final active = conn.activeDevice;

    return Scaffold(
      appBar: AppBar(title: const Text('Desktop PC Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Host Machine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _rowItem('Device Name', active?.name ?? 'Not Connected'),
                  _rowItem('Operating System', '${active?.operatingSystem ?? "Unknown"} ${active?.osVersion ?? ""}'),
                  _rowItem('Agent Version', active?.agentVersion ?? 'N/A'),
                  _rowItem('Current Transport', active?.transport.name.toUpperCase() ?? 'NONE'),
                  _rowItem('Latency', '${active?.latencyMs ?? 0} ms'),
                  _rowItem('Auth Status', active?.isTrusted == true ? 'Trusted & Authorized' : 'Pending Pairing'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Supported Capability Audits', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (active?.supportedFeatures ?? ['volume_control', 'brightness_control', 'mic_mute', 'app_launch', 'obs_control'])
                .map((f) => Chip(
                      label: Text(f),
                      avatar: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      backgroundColor: const Color(0xFF1E293B),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text('Desktop Execution Activity Logs (Sanitized)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: exec.activityLogs.isEmpty
                ? const Center(child: Text('No action commands executed yet.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    itemCount: exec.activityLogs.length,
                    itemBuilder: (ctx, idx) => Text(
                      exec.activityLogs[idx],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => exec.clearLogs(),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Log History'),
          ),
        ],
      ),
    );
  }

  // 3. Deck Appearance
  Widget _buildAppearanceSettings(BuildContext context, SettingsService settings) {
    final s = settings.settings;

    final accentColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEF4444), // Red
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Deck Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Preview Box
          Center(
            child: Container(
              width: 140,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(s.buttonCornerRadius),
                border: Border.all(color: s.accentColor, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: s.accentColor, size: 32),
                  if (s.showButtonLabels && !s.iconOnlyMode) ...[
                    const SizedBox(height: 6),
                    const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Theme Mode
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Text(s.themeMode.name.toUpperCase()),
            trailing: DropdownButton<ThemeMode>(
              value: s.themeMode,
              dropdownColor: const Color(0xFF1E293B),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
              onChanged: (v) => settings.updateSettings(themeMode: v!),
            ),
          ),
          const SizedBox(height: 12),

          // Accent Color
          const Text('Accent Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: accentColors.map((color) {
              final isSel = s.accentColor == color;
              return InkWell(
                onTap: () => settings.updateSettings(accentColor: color),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 3),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Corner Radius Slider
          ListTile(
            title: const Text('Button Corner Radius'),
            subtitle: Text('${s.buttonCornerRadius.round()} px'),
          ),
          Slider(
            value: s.buttonCornerRadius,
            min: 4,
            max: 32,
            activeColor: s.accentColor,
            onChanged: (v) => settings.updateSettings(buttonCornerRadius: v),
          ),

          // Spacing Slider
          ListTile(
            title: const Text('Grid Spacing'),
            subtitle: Text('${s.buttonSpacing.round()} px'),
          ),
          Slider(
            value: s.buttonSpacing,
            min: 6,
            max: 24,
            activeColor: s.accentColor,
            onChanged: (v) => settings.updateSettings(buttonSpacing: v),
          ),

          SwitchListTile(
            title: const Text('Show Button Labels'),
            value: s.showButtonLabels,
            onChanged: (v) => settings.updateSettings(showButtonLabels: v),
          ),
          SwitchListTile(
            title: const Text('Icon-Only Mode'),
            value: s.iconOnlyMode,
            onChanged: (v) => settings.updateSettings(iconOnlyMode: v),
          ),
          SwitchListTile(
            title: const Text('Haptic Vibration Feedback'),
            value: s.hapticFeedbackEnabled,
            onChanged: (v) => settings.updateSettings(hapticFeedbackEnabled: v),
          ),
        ],
      ),
    );
  }

  // 4. Layout & Button Editor
  Widget _buildLayoutEditorSettings(BuildContext context, ProfileService profileService) {
    final profile = profileService.currentProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Layout & Grid Presets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Grid Dimension Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _presetButton(profileService, '2 × 3', 2, 3, profile),
                      _presetButton(profileService, '3 × 3 (Standard)', 3, 3, profile),
                      _presetButton(profileService, '4 × 4 (XL)', 4, 4, profile),
                      _presetButton(profileService, '5 × 3 (Landscape)', 3, 5, profile),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Restore Default 9 Buttons'),
            subtitle: const Text('Reset current page buttons to default launcher layout'),
            trailing: OutlinedButton(
              onPressed: () {
                profileService.restoreNineButtonDefault();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restored default 9-button layout!')),
                );
              },
              child: const Text('Restore'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetButton(ProfileService service, String label, int rows, int cols, dynamic profile) {
    final isCurrent = profile.gridRows == rows && profile.gridCols == cols;
    return ChoiceChip(
      label: Text(label),
      selected: isCurrent,
      onSelected: (_) => service.updateGridDimensions(rows, cols),
    );
  }

  // 5. Audio & Brightness
  Widget _buildAudioBrightnessSettings(BuildContext context, SettingsService settings, DeckExecutionService exec) {
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Audio & Brightness Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Audio Output Routing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: s.currentAudioOutput,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Primary Playback Device'),
                    items: s.audioOutputs.map((out) => DropdownMenuItem(value: out, child: Text(out))).toList(),
                    onChanged: (v) => settings.updateSettings(currentAudioOutput: v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Volume Slider Step Delta'),
                    subtitle: Text('${s.volumeStep.round()}% per increment tap'),
                    trailing: DropdownButton<double>(
                      value: s.volumeStep,
                      dropdownColor: const Color(0xFF1E293B),
                      items: [2.0, 5.0, 10.0, 15.0].map((e) => DropdownMenuItem(value: e, child: Text('${e.round()}%'))).toList(),
                      onChanged: (v) => settings.updateSettings(volumeStep: v!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Display Brightness Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: s.currentDisplay,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Target Monitor'),
                    items: s.displays.map((disp) => DropdownMenuItem(value: disp, child: Text(disp))).toList(),
                    onChanged: (v) => settings.updateSettings(currentDisplay: v),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Use Hardware DDC/CI Brightness'),
                    subtitle: const Text('Adjusts actual monitor backlight instead of software gamma dimming'),
                    value: s.useHardwareBrightness,
                    onChanged: (v) => settings.updateSettings(useHardwareBrightness: v),
                  ),
                  ListTile(
                    title: const Text('Brightness Slider Step Delta'),
                    subtitle: Text('${s.brightnessStep.round()}% per tap'),
                    trailing: DropdownButton<double>(
                      value: s.brightnessStep,
                      dropdownColor: const Color(0xFF1E293B),
                      items: [5.0, 10.0, 15.0, 20.0].map((e) => DropdownMenuItem(value: e, child: Text('${e.round()}%'))).toList(),
                      onChanged: (v) => settings.updateSettings(brightnessStep: v!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. OBS Studio
  Widget _buildObsSettings(BuildContext context, ObsService obs) {
    final hostCtrl = TextEditingController(text: obs.config.host);
    final portCtrl = TextEditingController(text: obs.config.port.toString());
    final passCtrl = TextEditingController(text: obs.config.password);

    return Scaffold(
      appBar: AppBar(title: const Text('OBS Studio WebSocket v5')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable OBS Studio Integration'),
            subtitle: const Text('Allows AstraDeck to trigger scenes, mute audio & toggle streams'),
            value: obs.config.isEnabled,
            onChanged: (v) => obs.updateSettings(isEnabled: v),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'OBS Host IP')),
                  const SizedBox(height: 12),
                  TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'WebSocket Port (Default 4455)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Server Password (Encrypted locally, redacted from logs)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          obs.updateSettings(
                            host: hostCtrl.text.trim(),
                            port: int.tryParse(portCtrl.text) ?? 4455,
                            password: passCtrl.text,
                          );
                          obs.connect();
                        },
                        child: Text(obs.config.isConnected ? 'Reconnect OBS' : 'Connect OBS'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await obs.testConnection();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'OBS WebSocket Ping OK!' : 'Failed to reach OBS')),
                          );
                        },
                        child: const Text('Test Connection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Available Scenes in OBS', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...obs.config.availableScenes.map((scene) {
            final isCurrent = obs.config.currentScene == scene;
            return ListTile(
              leading: Icon(Icons.movie_creation, color: isCurrent ? Colors.redAccent : Colors.white70),
              title: Text(scene),
              trailing: isCurrent ? const Chip(label: Text('ACTIVE SCENE')) : null,
              onTap: () => obs.setScene(scene),
            );
          }),
        ],
      ),
    );
  }

  // 7. Profiles & Backup
  Widget _buildProfilesBackupSettings(BuildContext context, ProfileService profileService) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles & Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Colors.blueAccent),
              title: const Text('Export All Profiles to JSON'),
              subtitle: const Text('Generates complete portable backup (credentials sanitized)'),
              trailing: ElevatedButton(
                onPressed: () {
                  final json = profileService.exportAllProfilesToJson();
                  Clipboard.setData(ClipboardData(text: json));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All profiles backup copied to clipboard!')),
                  );
                },
                child: const Text('Copy JSON'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
              title: const Text('Restore Built-in Profiles'),
              subtitle: const Text('Restores Default, Streaming, Gaming, Productivity & Media'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  profileService.resetToDefaultProfiles();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restored factory default profiles!')),
                  );
                },
                child: const Text('Restore'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Security & Privacy
  Widget _buildSecuritySettings(BuildContext context, SettingsService settings, ConnectionService conn) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Require Confirmation for Sensitive Actions'),
            subtitle: const Text('Prompt alert before starting streams or closing applications'),
            value: settings.settings.requirePinForSensitiveActions,
            onChanged: (v) => settings.updateSettings(requirePinForSensitiveActions: v),
          ),
          SwitchListTile(
            title: const Text('Redact Sensitive Tokens in Diagnostic Logs'),
            subtitle: const Text('Ensures passwords, tokens and private IPs are scrubbed'),
            value: settings.settings.redactLogs,
            onChanged: (v) => settings.updateSettings(redactLogs: v),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Clear All Local Data & Config', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('Resets all profiles, stored credentials and settings'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => _confirmFullReset(context, settings, conn),
                child: const Text('Reset All'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 9. Notifications
  Widget _buildNotificationSettings(BuildContext context, SettingsService settings) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Alert on Desktop Disconnect'),
            subtitle: const Text('Show visual warning when link to PC is severed'),
            value: settings.settings.notifyOnDisconnect,
            onChanged: (v) => settings.updateSettings(notifyOnDisconnect: v),
          ),
          SwitchListTile(
            title: const Text('Notify on Profile Switching'),
            subtitle: const Text('Brief HUD banner indicating active profile change'),
            value: settings.settings.notifyOnProfileSwitch,
            onChanged: (v) => settings.updateSettings(notifyOnProfileSwitch: v),
          ),
        ],
      ),
    );
  }

  // 10. Advanced
  Widget _buildAdvancedSettings(BuildContext context, SettingsService settings) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('AstraDeck Protocol Specification'),
            subtitle: const Text('v2.4.0 (JSON-RPC over Secure WebSocket)'),
            trailing: const Icon(Icons.verified, color: Colors.greenAccent),
          ),
          ListTile(
            title: const Text('Keep-Alive Heartbeat Frequency'),
            subtitle: const Text('4000 ms'),
            trailing: const Icon(Icons.timer_outlined, color: Colors.white70),
          ),
          SwitchListTile(
            title: const Text('Lock App in Landscape Orientation'),
            value: settings.settings.lockOrientationLandscape,
            onChanged: (v) => settings.updateSettings(lockOrientationLandscape: v),
          ),
        ],
      ),
    );
  }

  // 11. About & Diagnostics
  Widget _buildDiagnosticsSettings(BuildContext context, ConnectionService conn, DeckExecutionService exec, ObsService obs) {
    final dev = conn.activeDevice;

    return Scaffold(
      appBar: AppBar(title: const Text('About & Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Diagnostic Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _rowItem('Mobile Client', 'AstraDeck Android v2.4.0'),
                  _rowItem('Desktop Agent', dev?.agentVersion ?? 'Not linked'),
                  _rowItem('Active Transport', dev?.transport.name.toUpperCase() ?? 'NONE'),
                  _rowItem('Link Latency', '${dev?.latencyMs ?? 0} ms'),
                  _rowItem('OBS WebSocket', obs.config.isConnected ? 'Connected' : 'Disconnected'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Run Hardware & Control Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.network_check, color: Colors.blueAccent),
            title: const Text('Test Connection & Round-Trip Ping'),
            trailing: ElevatedButton(
              onPressed: () async {
                if (dev != null) {
                  final ms = await conn.testConnection(dev);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Diagnostic Latency: ${ms}ms')));
                }
              },
              child: const Text('Run Test'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up, color: Colors.pinkAccent),
            title: const Text('Test Volume Adjustment (+5%)'),
            trailing: ElevatedButton(
              onPressed: () => exec.adjustVolume(5),
              child: const Text('Test Audio'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_medium, color: Colors.amber),
            title: const Text('Test Brightness (+10%)'),
            trailing: ElevatedButton(
              onPressed: () => exec.adjustBrightness(10),
              child: const Text('Test Display'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.greenAccent),
            title: const Text('Copy Sanitized Diagnostic Report'),
            trailing: ElevatedButton(
              onPressed: () {
                final report = '''=== AstraDeck Diagnostic Report ===
Client: AstraDeck v2.4.0 (Flutter 3.49 / Android)
Connected Host: ${dev?.name ?? "None"}
OS: ${dev?.operatingSystem ?? "N/A"}
Transport: ${dev?.transport.name ?? "None"}
Latency: ${dev?.latencyMs ?? 0}ms
OBS Status: ${obs.config.isConnected ? "Active" : "Inactive"}
Timestamp: ${DateTime.now().toIso8601String()}
Logs: [REDACTED FOR PRIVACY]
====================================''';
                Clipboard.setData(ClipboardData(text: report));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sanitized report copied to clipboard!')),
                );
              },
              child: const Text('Copy Report'),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _rowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        ],
      ),
    );
  }

  void _confirmFullReset(BuildContext context, SettingsService settings, ConnectionService conn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirm Data Wipe'),
        content: const Text('This will reset all settings, paired machines and profile customizations to factory condition.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await settings.resetToDefaults();
              conn.disconnectAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Factory reset complete!')),
              );
            },
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }
}

class _SettingCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _SettingCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
