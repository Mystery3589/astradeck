import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/desktop_device.dart';
import '../../services/connection_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/connect_pc_modal.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionService = context.watch<ConnectionService>();
    final settingsService = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Manager'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: settingsService.settings.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi / LAN'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth Classic'),
            Tab(icon: Icon(Icons.usb), text: 'USB Mode'),
            Tab(icon: Icon(Icons.verified_user), text: 'Trusted Devices'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWifiTab(context, connectionService, settingsService),
          _buildBluetoothTab(context, connectionService, settingsService),
          _buildUsbTab(context, connectionService, settingsService),
          _buildTrustedTab(context, connectionService, settingsService),
        ],
      ),
    );
  }

  // --- 1. Wi-Fi / LAN Tab ---
  Widget _buildWifiTab(BuildContext context, ConnectionService service, SettingsService settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pair Fresh PC banner
        Card(
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: settings.settings.accentColor.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: settings.settings.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome, color: settings.settings.accentColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connecting to a Fresh PC?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('1-click auto-setup for Linux, Windows, & Mac.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: settings.settings.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => ConnectPcModal.show(context),
                  child: const Text('Setup Guide', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Action Bar: Scan + Add Manually
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settings.settings.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: service.isScanning ? null : () => service.scanForDevices(),
                icon: service.isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.radar),
                label: Text(service.isScanning ? 'Scanning Network...' : 'Auto-Discover PCs'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                side: const BorderSide(color: Color(0xFF334155)),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showManualAddDialog(context, service),
              icon: const Icon(Icons.add),
              label: const Text('Add IP/Port'),
            ),
          ],
        ),

        if (service.lastError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.lastError!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const Text('Discovered & Configured Computers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),

        Builder(builder: (context) {
          final wifiDevices = service.devices.where((d) => d.transport == ConnectionTransport.wifi).toList();
          if (wifiDevices.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No Wi-Fi computers found.\nTap "Auto-Discover PCs" or enter IP manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            );
          }
          return Column(
            children: wifiDevices.map((device) => _buildDeviceCard(context, device, service, settings)).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildDeviceCard(BuildContext context, DesktopDevice device, ConnectionService service, SettingsService settings) {
    final isConnected = device.status == ConnectionStatus.connected;
    final isConnecting = device.status == ConnectionStatus.connecting;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConnected ? const Color(0xFF10B981) : const Color(0xFF334155),
          width: isConnected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFF0F172A),
                  child: Icon(
                    device.operatingSystem.toLowerCase().contains('linux')
                        ? Icons.terminal
                        : Icons.desktop_windows,
                    color: isConnected ? const Color(0xFF10B981) : Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (device.isPreferred) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                          ],
                        ],
                      ),
                      Text(
                        '${device.operatingSystem} ${device.osVersion} • Agent v${device.agentVersion}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${device.ipAddress}:${device.port}${device.hostname.isNotEmpty ? " (${device.hostname})" : ""}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${device.latencyMs} ms',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!device.isTrusted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Unpaired', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Trusted', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final lat = await service.testConnection(device);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ping to ${device.name}: ${lat}ms')),
                        );
                      },
                      child: const Text('Test Ping', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ),
                    const SizedBox(width: 4),
                    if (isConnected)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => service.disconnect(device),
                        child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: settings.settings.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: isConnecting
                            ? null
                            : () => _promptConnect(context, service, device),
                        child: isConnecting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Connect', style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Forget device',
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF64748B)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text('Forget device?', style: TextStyle(color: Colors.white)),
                            content: Text('Remove "${device.name}" from the list?', style: const TextStyle(color: Color(0xFF94A3B8))),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Forget', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) service.forgetDevice(device.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Bluetooth Classic Tab ---
  Widget _buildBluetoothTab(BuildContext context, ConnectionService service, SettingsService settings) {
    final pairedDevices = service.discoveredBluetoothDevices.where((d) => d['bonded'] == true).toList();
    final nearbyDevices = service.discoveredBluetoothDevices.where((d) => d['bonded'] != true).toList();
    final isConnected = service.isBtConnected;
    final connectedAddress = service.btConnectedAddress;
    final connectingAddress = service.btConnectingAddress;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Status & Scan Control Header Card
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        color: isConnected
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: isConnected ? const Color(0xFF10B981) : Colors.blueAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? 'Bluetooth Connected' : 'Bluetooth RFCOMM',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnected
                                ? 'Active link to companion on Channel 4'
                                : 'Direct wireless link without Wi-Fi router',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: settings.settings.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: service.isBluetoothScanning
                          ? () => service.stopBluetoothScan()
                          : () => service.scanBluetooth(),
                      icon: service.isBluetoothScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bluetooth_searching, size: 18),
                      label: Text(service.isBluetoothScanning ? 'Scanning... (Stop)' : 'Search Nearby Devices'),
                    ),
                    if (isConnected)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => service.disconnectBluetooth(),
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Disconnect'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Active Bluetooth Connection Banner (if connected)
        if (isConnected) ...[
          Card(
            color: const Color(0xFF0F2E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.activeDevice?.name ?? 'Connected PC',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'MAC: $connectedAddress • Latency: ${service.activeDevice?.latencyMs ?? 0}ms',
                          style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Paired Devices Section
        Row(
          children: [
            const Icon(Icons.devices, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 6),
            const Text(
              'Paired Devices',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pairedDevices.length}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (pairedDevices.isEmpty && !service.isBluetoothScanning)
          Card(
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No paired Bluetooth devices found.\nTap "Search Nearby Devices" to pair your PC.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...pairedDevices.map((bt) {
            final addr = bt['address']?.toString() ?? '';
            final name = bt['name']?.toString() ?? addr;
            final isThisConnected = isConnected && connectedAddress == addr;
            final isThisConnecting = connectingAddress == addr;

            return Card(
              color: isThisConnected ? const Color(0xFF1E293B) : const Color(0xFF141E30),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isThisConnected ? const Color(0xFF10B981) : const Color(0xFF334155),
                  width: isThisConnected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isThisConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isThisConnected ? Icons.bluetooth_connected : Icons.computer,
                    color: isThisConnected ? const Color(0xFF10B981) : Colors.white70,
                    size: 20,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Address: $addr',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                trailing: isThisConnected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CONNECTED',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      )
                    : isThisConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: settings.settings.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => service.connectBluetooth(addr, name: name),
                            child: const Text('Connect'),
                          ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // 4. Nearby Discovered Devices Section (Unbonded)
        if (nearbyDevices.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.radar, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              const Text(
                'Nearby Devices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${nearbyDevices.length}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...nearbyDevices.map((bt) {
            final addr = bt['address']?.toString() ?? '';
            final name = bt['name']?.toString() ?? addr;
            final isThisConnecting = connectingAddress == addr;

            return Card(
              color: const Color(0xFF141E30),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bluetooth_searching, color: Colors.amber, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'MAC: $addr',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                trailing: isThisConnecting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => service.connectBluetooth(addr, name: name),
                        child: const Text('Pair & Connect'),
                      ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // --- 3. USB Mode Tab ---
  Widget _buildUsbTab(BuildContext context, ConnectionService service, SettingsService settings) {
    final usbDevice = service.devices.where((d) => d.id == 'usb_tether' || d.id == 'usb_localhost').firstOrNull;
    final isConnected = usbDevice?.status == ConnectionStatus.connected;
    final isConnecting = usbDevice?.status == ConnectionStatus.connecting || service.isUsbConnecting;

    Color statusColor;
    String statusLabel;
    if (isConnected) {
      statusColor = const Color(0xFF10B981);
      statusLabel = usbDevice?.id == 'usb_tether' ? 'USB Tethering Active' : 'ADB Reverse Active';
    } else if (isConnecting) {
      statusColor = Colors.amber;
      statusLabel = 'Connecting...';
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Offline';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Primary USB Mode: USB Tethering (No ADB / No Developer Options)
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isConnected ? const Color(0xFF10B981) : const Color(0xFF334155),
              width: isConnected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.usb, color: Colors.tealAccent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'USB Cable (Plug & Play)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'No Developer Options or ADB required! Plug in USB cable, turn on USB Tethering, and connect with sub-1ms physical latency.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Status & details box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isConnected
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Text(
                    service.usbDeviceDetails,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isConnected ? const Color(0xFF10B981) : Colors.white70,
                    ),
                  ),
                ),

                if (isConnected && usbDevice != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.network_ping, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Latency: ${usbDevice.latencyMs} ms (<1ms Physical USB)',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                if (isConnected)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: usbDevice != null ? () => service.disconnect(usbDevice) : null,
                          icon: const Icon(Icons.link_off, size: 16),
                          label: const Text('Disconnect USB'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        onPressed: () async {
                          if (usbDevice != null) {
                            final lat = await service.testConnection(usbDevice);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('USB Round-Trip: ${lat}ms')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.network_ping, size: 16),
                        label: const Text('Ping'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.tealAccent,
                                side: const BorderSide(color: Colors.tealAccent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => service.openTetheringSettings(),
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Open Tethering Settings'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: settings.settings.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: isConnecting ? null : () => service.checkUsbStatus(preferAdb: false),
                              icon: isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bolt, size: 16),
                              label: Text(isConnecting ? 'Connecting...' : 'Connect (No ADB)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Secondary Developer Option (ADB Reverse)
        Card(
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.developer_mode, color: Color(0xFF38BDF8), size: 20),
            title: const Text(
              'Developer Option: Connect via ADB',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: const Text(
              'Requires USB Debugging enabled in phone Developer Options',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                'Uses "adb reverse tcp:8765 tcp:8765" over localhost. Once enabled, connects automatically in the background without touching tethering settings.',
                style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isConnecting ? null : () => service.checkUsbStatus(preferAdb: true),
                  icon: const Icon(Icons.terminal, size: 16),
                  label: const Text('Connect via ADB Reverse'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Universal 4 Connection Methods Reference Card
        Card(
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub, color: Colors.tealAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '4 Universal Connection Methods',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _methodRow(
                  '1. USB Tethering',
                  '< 1 ms',
                  'Best zero-developer option. Plug cable & toggle USB Tethering.',
                  Colors.tealAccent,
                  Icons.usb,
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                _methodRow(
                  '2. Local Wi-Fi',
                  '3–8 ms',
                  'Zero-cable wireless. Auto-discovered via UDP beacon.',
                  Colors.blueAccent,
                  Icons.wifi,
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                _methodRow(
                  '3. Bluetooth',
                  '12–25 ms',
                  'Zero-router link. Standard Bluetooth pairing via RFCOMM.',
                  Colors.indigoAccent,
                  Icons.bluetooth,
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                _methodRow(
                  '4. AOA 2.0 (Roadmap)',
                  '< 1 ms',
                  'Native Android Open Accessory protocol for direct USB host link.',
                  Colors.purpleAccent,
                  Icons.cable,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _methodRow(String title, String latency, String desc, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(latency, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. Trusted Devices Tab ---
  Widget _buildTrustedTab(BuildContext context, ConnectionService service, SettingsService settings) {
    final trusted = service.devices.where((d) => d.isTrusted).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Authorized Desktops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 16),
              label: const Text('Disconnect All', style: TextStyle(color: Colors.redAccent)),
              onPressed: () => service.disconnectAll(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (trusted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No trusted devices authorized yet.\nPair a PC in the Wi-Fi or Bluetooth tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ...trusted.map((d) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.security, color: Color(0xFF10B981)),
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('IP: ${d.ipAddress} • Last used: ${d.lastConnected?.toString().substring(0, 16) ?? "Recently"}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'preferred') {
                      service.setPreferredDevice(d.id);
                    } else if (val == 'revoke') {
                      service.revokeTrust(d.id);
                    } else if (val == 'forget') {
                      service.forgetDevice(d.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'preferred',
                      child: Text(d.isPreferred ? 'Default Device (Active)' : 'Set as Default'),
                    ),
                    const PopupMenuItem(value: 'revoke', child: Text('Revoke PIN Credentials')),
                    const PopupMenuItem(
                      value: 'forget',
                      child: Text('Forget Device', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _promptConnect(BuildContext context, ConnectionService service, DesktopDevice device) {
    if (device.isTrusted) {
      service.connectTo(device);
      return;
    }

    final pinCtrl = TextEditingController(text: '1234');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Pair with ${device.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 4-digit pairing PIN shown on your desktop AstraDeck agent window (Default test PIN: 1234):',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final pin = pinCtrl.text.trim();
              Navigator.of(ctx).pop();
              service.connectTo(device, pin: pin);
            },
            child: const Text('Pair & Connect'),
          ),
        ],
      ),
    ).then((_) => pinCtrl.dispose());
  }

  void _showManualAddDialog(BuildContext context, ConnectionService service) {
    final ipCtrl = TextEditingController(text: '192.168.1.');
    final portCtrl = TextEditingController(text: '8765');
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Desktop Host Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Device Name (Optional)')),
            const SizedBox(height: 8),
            TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP Address')),
            const SizedBox(height: 8),
            TextField(controller: portCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final ip = ipCtrl.text.trim();
              final name = nameCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 8765;
              if (ip.isNotEmpty) {
                Navigator.of(ctx).pop();
                service.addManualDevice(
                  name: name,
                  ipAddress: ip,
                  port: port,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      ipCtrl.dispose();
      portCtrl.dispose();
      nameCtrl.dispose();
    });
  }
}
