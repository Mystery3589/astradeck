import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../services/settings_service.dart';

class ConnectPcModal extends StatefulWidget {
  const ConnectPcModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ConnectPcModal(),
    );
  }

  @override
  State<ConnectPcModal> createState() => _ConnectPcModalState();
}

class _ConnectPcModalState extends State<ConnectPcModal>
    with SingleTickerProviderStateMixin {
  int _selectedOsIndex = 0; // 0: Linux, 1: Windows, 2: macOS
  int _selectedTransportIndex = 0; // 0: USB, 1: Wi-Fi, 2: Bluetooth
  bool _autoSetupAdb = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late ConnectionService _connectionService;

  List<Map<String, String>> get _osCommands => [
    {
      'os': 'Linux',
      'icon': '🐧',
      'desc': _autoSetupAdb
          ? 'Downloads companion, auto-configures ADB reverse tunnel, & installs systemd service.'
          : 'Downloads companion & installs auto-start systemd service (Zero ADB / No Developer Options needed!).',
      'cmd': _autoSetupAdb
          ? 'curl -sSL https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.sh | bash -s -- --adb'
          : 'curl -sSL https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.sh | bash',
    },
    {
      'os': 'Windows',
      'icon': '🪟',
      'desc': _autoSetupAdb
          ? 'Paste in PowerShell: auto-installs ADB, companion, & configures silent auto-start.'
          : 'Paste in PowerShell: downloads companion & configures silent auto-start (No ADB needed).',
      'cmd': _autoSetupAdb
          ? r'$env:ASTRADECK_ADB=1; irm https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.ps1 | iex'
          : 'irm https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.ps1 | iex',
    },
    {
      'os': 'macOS',
      'icon': '🍏',
      'desc': _autoSetupAdb
          ? 'Downloads companion, auto-configures ADB reverse tunnel, & installs LaunchAgent.'
          : 'Downloads companion & installs auto-start LaunchAgent (No ADB needed).',
      'cmd': _autoSetupAdb
          ? 'curl -sSL https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.sh | bash -s -- --adb'
          : 'curl -sSL https://raw.githubusercontent.com/Mystery3589/astradeck/main/server/setup.sh | bash',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If not connected, start polling to detect companion; do NOT auto-dismiss abruptly if already connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_connectionService.isConnected) {
        _connectionService.startLivePolling(onConnected: () {
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _connectionService = context.read<ConnectionService>();
  }

  @override
  void dispose() {
    _connectionService.stopLivePolling();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionService = context.watch<ConnectionService>();
    final settingsService = context.watch<SettingsService>();
    final accent = settingsService.settings.accentColor;
    final currentOs = _osCommands[_selectedOsIndex];
    final isConnected = connectionService.isConnected;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                ScaleTransition(
                  scale: isConnected ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isConnected ? const Color(0xFF10B981) : accent).withValues(alpha: 0.15),
                      border: Border.all(color: isConnected ? const Color(0xFF10B981) : accent, width: 1.5),
                    ),
                    child: Icon(
                      isConnected ? Icons.check_circle : Icons.radar,
                      color: isConnected ? const Color(0xFF10B981) : accent,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PC Companion Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isConnected
                            ? 'Connected to ${connectionService.activeDevice?.name ?? "PC"} (${connectionService.activeDevice?.latencyMs ?? 0}ms)'
                            : 'Scanning USB, Wi-Fi, & Bluetooth...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Transport Selector (USB, Wi-Fi, Bluetooth)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTransportTab(0, Icons.usb, 'USB Cable'),
                  _buildTransportTab(1, Icons.wifi, 'Wi-Fi / LAN'),
                  _buildTransportTab(2, Icons.bluetooth, 'Bluetooth'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Transport Tips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedTransportIndex == 0
                        ? Icons.bolt
                        : _selectedTransportIndex == 1
                            ? Icons.network_check
                            : Icons.bluetooth_searching,
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedTransportIndex == 0
                          ? 'USB: Sub-1ms latency. USB Tethering works with zero developer options!'
                          : _selectedTransportIndex == 1
                              ? 'Wi-Fi / LAN: Zero-cable, 3-8ms. Auto-discovers companion on local network.'
                              : 'Bluetooth: Zero-router, 12-25ms. Pair phone with PC in Bluetooth settings.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedTransportIndex == 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cable, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'USB Tethering (Zero Developer Options)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Plug USB cable & turn on USB Tethering for instant sub-1ms speed.',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => connectionService.openTetheringSettings(),
                      child: const Text('Open Settings', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            const Text(
              '1-Click Setup on PC (Runs once, sets up auto-start):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // OS Tabs
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: List.generate(_osCommands.length, (idx) {
                  final item = _osCommands[idx];
                  final isSelected = _selectedOsIndex == idx;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedOsIndex = idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item['icon']} ${item['os']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // Auto-setup ADB Switch Card (Secondary / Developer Option)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _autoSetupAdb ? accent.withValues(alpha: 0.6) : const Color(0xFF334155),
                  width: _autoSetupAdb ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (_autoSetupAdb ? accent : const Color(0xFF64748B)).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.developer_mode,
                      size: 16,
                      color: _autoSetupAdb ? accent : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADB Reverse Tunnel (Developer Mode)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _autoSetupAdb
                              ? 'Command installs Google ADB platform-tools on PC (requires USB Debugging on phone)'
                              : 'Without ADB: Uses USB Tethering or Wi-Fi (Plug & play, zero developer options)',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoSetupAdb,
                    activeThumbColor: accent,
                    onChanged: (val) => setState(() => _autoSetupAdb = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Command Box with Copy Button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentOs['cmd']!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                    tooltip: 'Copy Command',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: currentOs['cmd']!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Command copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              currentOs['desc']!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => connectionService.autoConnect(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Probe Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => connectionService.checkUsbStatus(),
                    icon: const Icon(Icons.usb, size: 16),
                    label: const Text('USB Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportTab(int index, IconData icon, String label) {
    final isSelected = _selectedTransportIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTransportIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
