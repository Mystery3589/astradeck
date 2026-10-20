package com.nexusdeck.nexus_deck

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.nio.charset.StandardCharsets
import java.util.UUID

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val METHOD_CHANNEL = "com.astradeck/bluetooth"
    private val EVENT_CHANNEL = "com.astradeck/bluetooth_events"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val PERMISSION_REQUEST_CODE = 4412

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activeSocket: BluetoothSocket? = null
    private var activeOutputStream: OutputStream? = null
    private var isSocketConnected = false
    private var connectionThread: Thread? = null
    private var receiverRegistered = false
    private var connectionSessionId = 0

    private val discoveryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val device: BluetoothDevice? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(
                                BluetoothDevice.EXTRA_DEVICE,
                                BluetoothDevice::class.java
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                    device?.let {
                        val name = getDeviceName(it)
                        val bonded = hasPermission(Manifest.permission.BLUETOOTH_CONNECT) &&
                                it.bondState == BluetoothDevice.BOND_BONDED
                        postEvent(
                            mapOf(
                                "event" to "device_found",
                                "name" to name,
                                "address" to it.address,
                                "bonded" to bonded
                            )
                        )
                    }
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    postEvent(mapOf("event" to "discovery_finished"))
                }
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    val enabled = state == BluetoothAdapter.STATE_ON
                    postEvent(
                        mapOf(
                            "event" to "state_changed",
                            "enabled" to enabled
                        )
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isBluetoothSupported" -> {
                result.success(bluetoothAdapter != null)
            }
            "isBluetoothEnabled" -> {
                result.success(bluetoothAdapter?.isEnabled == true)
            }
            "requestEnableBluetooth" -> {
                if (bluetoothAdapter?.isEnabled == false) {
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    startActivity(enableBtIntent)
                    result.success(true)
                } else {
                    result.success(true)
                }
            }
            "checkPermissions" -> {
                result.success(hasRequiredPermissions())
            }
            "requestPermissions" -> {
                requestRequiredPermissions()
                result.success(true)
            }
            "getBondedDevices" -> {
                val devicesList = mutableListOf<Map<String, Any>>()
                if (hasRequiredPermissions() && bluetoothAdapter?.isEnabled == true) {
                    bluetoothAdapter?.bondedDevices?.forEach { device ->
                        devicesList.add(
                            mapOf(
                                "name" to getDeviceName(device),
                                "address" to device.address,
                                "bonded" to true
                            )
                        )
                    }
                }
                result.success(devicesList)
            }
            "startDiscovery" -> {
                if (!hasRequiredPermissions()) {
                    result.error("PERMISSION_DENIED", "Missing Bluetooth permissions", null)
                    return
                }
                if (bluetoothAdapter?.isEnabled != true) {
                    result.error("BT_DISABLED", "Bluetooth is disabled", null)
                    return
                }
                registerDiscoveryReceiver()
                if (bluetoothAdapter?.isDiscovering == true) {
                    bluetoothAdapter?.cancelDiscovery()
                }
                val started = bluetoothAdapter?.startDiscovery() ?: false
                result.success(started)
            }
            "stopDiscovery" -> {
                if (hasRequiredPermissions() && bluetoothAdapter?.isDiscovering == true) {
                    bluetoothAdapter?.cancelDiscovery()
                }
                result.success(true)
            }
            "connect" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "Device address is required", null)
                    return
                }
                connectToDevice(address, result)
            }
            "disconnect" -> {
                disconnectDevice()
                result.success(true)
            }
            "sendData" -> {
                val data = call.argument<String>("data")
                if (data == null) {
                    result.error("INVALID_ARGS", "Data is required", null)
                    return
                }
                val ok = writeData(data)
                result.success(ok)
            }
            "isConnected" -> {
                result.success(isSocketConnected)
            }
            "openTetheringSettings" -> {
                try {
                    val intent = Intent().apply {
                        action = "android.settings.TETHER_SETTINGS"
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val fallback = Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(fallback)
                        result.success(true)
                    } catch (e2: Exception) {
                        result.error("INTENT_ERROR", e2.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // --- Bluetooth Connection Lifecycle ---

    private fun connectToDevice(address: String, result: MethodChannel.Result) {
        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Missing Bluetooth permissions", null)
            return
        }
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_DISABLED", "Bluetooth is disabled", null)
            return
        }

        val mySessionId = ++connectionSessionId
        disconnectDevice()

        if (adapter.isDiscovering) {
            adapter.cancelDiscovery()
        }

        val device: BluetoothDevice
        try {
            device = adapter.getRemoteDevice(address)
        } catch (e: Exception) {
            result.error("DEVICE_NOT_FOUND", "Invalid MAC address: ${e.message}", null)
            return
        }

        result.success(true) // Immediate acknowledgement, async status streamed via events

        connectionThread = Thread {
            if (mySessionId != connectionSessionId) return@Thread
            var socket: BluetoothSocket? = null
            var lastError: String? = null

            // 1. Try reflection on port 4 (AstraDeck Linux RFCOMM default channel)
            try {
                val m = device.javaClass.getMethod("createInsecureRfcommSocket", Int::class.javaPrimitiveType)
                socket = m.invoke(device, 4) as BluetoothSocket
                socket.connect()
            } catch (e: Exception) {
                lastError = e.message
                socket = null
            }

            // 2. Fallback to reflection port 4 with secure socket
            if (socket == null || !socket.isConnected) {
                try {
                    val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    socket = m.invoke(device, 4) as BluetoothSocket
                    socket.connect()
                } catch (e: Exception) {
                    lastError = e.message
                    socket = null
                }
            }

            // 3. Fallback to Standard SPP UUID (Insecure)
            if (socket == null || !socket.isConnected) {
                try {
                    socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                    socket.connect()
                } catch (e: Exception) {
                    lastError = e.message
                    socket = null
                }
            }

            // 4. Fallback to Standard SPP UUID (Secure)
            if (socket == null || !socket.isConnected) {
                try {
                    socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                    socket.connect()
                } catch (e: Exception) {
                    lastError = e.message
                    socket = null
                }
            }

            if (mySessionId != connectionSessionId) {
                try { socket?.close() } catch (_: Exception) {}
                return@Thread
            }

            if (socket != null && socket.isConnected) {
                activeSocket = socket
                activeOutputStream = socket.outputStream
                isSocketConnected = true

                postEvent(
                    mapOf(
                        "event" to "connected",
                        "address" to address,
                        "name" to getDeviceName(device)
                    )
                )

                // Reader loop
                try {
                    val reader = BufferedReader(InputStreamReader(socket.inputStream, StandardCharsets.UTF_8))
                    while (isSocketConnected && mySessionId == connectionSessionId) {
                        val line = reader.readLine() ?: break
                        if (line.isNotBlank()) {
                            postEvent(
                                mapOf(
                                    "event" to "data",
                                    "message" to line.trim()
                                )
                            )
                        }
                    }
                } catch (e: Exception) {
                    lastError = e.message
                } finally {
                    if (mySessionId == connectionSessionId) {
                        disconnectDevice()
                        postEvent(
                            mapOf(
                                "event" to "disconnected",
                                "error" to (lastError ?: "Connection closed")
                            )
                        )
                    }
                }
            } else {
                if (mySessionId == connectionSessionId) {
                    postEvent(
                        mapOf(
                            "event" to "connect_failed",
                            "error" to (lastError ?: "Could not connect to RFCOMM socket on $address")
                        )
                    )
                }
            }
        }.apply {
            name = "AstraDeck-BT-Worker"
            isDaemon = true
            start()
        }
    }

    private fun writeData(data: String): Boolean {
        return try {
            val stream = activeOutputStream ?: return false
            val payload = if (data.endsWith("\n")) data else "$data\n"
            stream.write(payload.toByteArray(StandardCharsets.UTF_8))
            stream.flush()
            true
        } catch (e: Exception) {
            disconnectDevice()
            postEvent(
                mapOf(
                    "event" to "disconnected",
                    "error" to (e.message ?: "Write failed")
                )
            )
            false
        }
    }

    private fun disconnectDevice() {
        isSocketConnected = false
        try {
            activeOutputStream?.close()
        } catch (_: Exception) {}
        try {
            activeSocket?.close()
        } catch (_: Exception) {}
        activeOutputStream = null
        activeSocket = null
    }

    // --- Permissions & Utilities ---

    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasPermission(Manifest.permission.BLUETOOTH_CONNECT) &&
                    hasPermission(Manifest.permission.BLUETOOTH_SCAN)
        } else {
            hasPermission(Manifest.permission.BLUETOOTH) &&
                    hasPermission(Manifest.permission.BLUETOOTH_ADMIN) &&
                    hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasPermission(perm: String): Boolean {
        return ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestRequiredPermissions() {
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
        ActivityCompat.requestPermissions(this, perms, PERMISSION_REQUEST_CODE)
    }

    private fun getDeviceName(device: BluetoothDevice): String {
        return try {
            if (hasPermission(Manifest.permission.BLUETOOTH_CONNECT)) {
                device.name ?: device.address
            } else {
                device.address
            }
        } catch (_: Exception) {
            device.address
        }
    }

    private fun registerDiscoveryReceiver() {
        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_FOUND)
                addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(discoveryReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(discoveryReceiver, filter)
            }
            receiverRegistered = true
        }
    }

    private fun postEvent(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        registerDiscoveryReceiver()
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        if (receiverRegistered) {
            try {
                unregisterReceiver(discoveryReceiver)
            } catch (_: Exception) {}
            receiverRegistered = false
        }
    }

    override fun onDestroy() {
        disconnectDevice()
        if (receiverRegistered) {
            try {
                unregisterReceiver(discoveryReceiver)
            } catch (_: Exception) {}
            receiverRegistered = false
        }
        super.onDestroy()
    }
}
