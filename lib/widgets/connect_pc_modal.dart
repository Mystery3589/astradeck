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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> _osCommands = [
    {
      'os': 'Linux',
      'icon': '🐧',
      'desc': 'Downloads companion & installs auto-start systemd service (zero files needed!).',
      'cmd': 'curl -sSL https://raw.githubusercontent.com/mystery/OneClick/main/server/setup.sh | bash',
    },
    {
      'os': 'Windows',
      'icon': '🪟',
      'desc': 'Paste in PowerShell: downloads companion & configures silent auto-start.',
      'cmd': 'irm https://raw.githubusercontent.com/mystery/OneClick/main/server/setup.ps1 | iex',
    },
    {
      'os': 'macOS',
      'icon': '🍏',
      'desc': 'Downloads companion & installs auto-start LaunchAgent.',
      'cmd': 'curl -sSL https://raw.githubusercontent.com/mystery/OneClick/main/server/setup.sh | bash',
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

    // Start live poller while modal is open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conn = context.read<ConnectionService>();
      conn.startLivePolling(onConnected: () {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to ${conn.activeDevice?.name ?? "PC"}!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionService = context.watch<ConnectionService>();
    final settingsService = context.watch<SettingsService>();
    final accent = settingsService.settings.accentColor;
    final currentOs = _osCommands[_selectedOsIndex];

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

            // Header with pulsing radar
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.15),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: Icon(Icons.radar, color: accent, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect to this PC',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        connectionService.isConnected
                            ? 'Server detected! Connecting...'
                            : 'Scanning USB, Wi-Fi, & Bluetooth...',
                        style: TextStyle(
                          fontSize: 12,
                          color: connectionService.isConnected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                        ),
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
                          ? 'USB: Lowest latency (<2ms). Probing ports 8765-8780.'
                          : _selectedTransportIndex == 1
                              ? 'Wi-Fi: Ensure phone and PC are on the same local network.'
                              : 'Bluetooth: Pair phone with PC in Bluetooth settings for zero-router link.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),

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
            Row(
              children: List.generate(_osCommands.length, (idx) {
                final item = _osCommands[idx];
                final isSelected = _selectedOsIndex == idx;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: idx < 2 ? 8 : 0),
                    child: ChoiceChip(
                      label: Text('${item['icon']} ${item['os']}'),
                      selected: isSelected,
                      selectedColor: accent,
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedOsIndex = idx),
                    ),
                  ),
                );
              }),
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
        onTap: () => setState(() => _selectedTransportIndex = index),
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
