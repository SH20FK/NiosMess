package com.niosmess.pulse

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.UUID

/** No device addresses or account identifiers cross the Flutter channel or logs. */
@SuppressLint("MissingPermission")
internal class BluetoothMeshPlugin(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val app = activity.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val methods = MethodChannel(messenger, "app.niosmess/bluetooth_mesh")
    private val events = EventChannel(messenger, "app.niosmess/bluetooth_mesh/events")
    private var sink: EventChannel.EventSink? = null
    private val manager = app.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
    private var lease = ""
    private var state = "stopped"
    private var running = false
    private var server: BluetoothGattServer? = null
    private var characteristic: BluetoothGattCharacteristic? = null
    private val peers = linkedMapOf<String, Peer>()
    private val visited = linkedMapOf<String, Long>()
    private var nextPeer = 0
    private data class AccessRequest(val lease: String, val result: MethodChannel.Result, val startAfter: Boolean)
    private var pendingPermission: AccessRequest? = null
    private var pendingEnable: AccessRequest? = null
    private var scanCycle: Runnable? = null

    private inner class Peer(val key: String, val device: BluetoothDevice, val client: Boolean) {
        val id = "p${++nextPeer}"
        val generation = lease
        var gatt: BluetoothGatt? = null
        var remote: BluetoothGattCharacteristic? = null
        var mtu = 23
        var ready = false
        var busy = false
        var queuedBytes = 0
        var touched = SystemClock.elapsedRealtime()
        val chunks = ArrayDeque<ByteArray>()
        val decoder = BleFrameCodec { SystemClock.elapsedRealtime() }
    }
    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAccess" -> {
                    val requested = call.argument<String>("lease")
                    if (requested.isNullOrEmpty() || requested.length > 64) result.error("INVALID", "Invalid lease", null)
                    else requestAccess(requested, result, false)
                }
                "start" -> {
                    val requested = call.argument<String>("lease")
                    if (requested.isNullOrEmpty() || requested.length > 64) result.error("INVALID", "Invalid lease", null)
                    else start(requested, call.argument<Boolean>("requestPermission") == true, result)
                }
                "stop" -> {
                    if (call.argument<String>("lease") == lease) stop()
                    result.success(null)
                }
                "send" -> {
                    val peer = peers.values.firstOrNull { it.id == call.argument<String>("peer") }
                    val data = call.argument<ByteArray>("data")
                    if (call.argument<String>("lease") != lease || peer == null || !peer.ready || data == null ||
                        data.isEmpty() || data.size > BleFrameCodec.MAX_FRAME || peer.queuedBytes + data.size > 262144) {
                        result.error("UNAVAILABLE", "Bluetooth peer unavailable", null)
                    } else {
                        val chunks = BleFrameCodec.encode(data, minOf(244, maxOf(20, peer.mtu - 3)))
                        peer.chunks.addAll(chunks); peer.queuedBytes += chunks.sumOf { it.size }
                        transmit(peer); result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun status() = mapOf("state" to state)
    private fun event(values: Map<String, Any>) { sink?.success(mapOf("lease" to lease) + values) }
    private fun state(value: String) { state = value; event(mapOf("type" to "status", "state" to value)) }
    private fun permissions(): Array<String> = if (Build.VERSION.SDK_INT >= 31) arrayOf(
        Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    private fun permitted() = permissions().all { ContextCompat.checkSelfPermission(app, it) == PackageManager.PERMISSION_GRANTED }

    private fun requestAccess(requested: String, result: MethodChannel.Result, startAfter: Boolean) {
        if (requested != lease) { stop(); lease = requested }
        if (manager?.adapter == null) { state("unsupported"); result.success(status()); return }
        if (pendingPermission != null || pendingEnable != null) { result.success(mapOf("state" to "starting")); return }
        val request = AccessRequest(requested, result, startAfter)
        if (!permitted()) {
            state("permission_required"); pendingPermission = request
            try { ActivityCompat.requestPermissions(activity, permissions(), PERMISSION_REQUEST) }
            catch (_: Exception) { pendingPermission = null; state("unavailable"); result.success(status()) }
        } else finishAccess(request)
    }
    private fun finishAccess(request: AccessRequest) {
        if (request.lease != lease) { request.result.success(mapOf("state" to "stopped")); return }
        try {
            if (manager?.adapter?.isEnabled != true) {
                state("bluetooth_off"); pendingEnable = request
                activity.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), ENABLE_REQUEST)
            } else if (request.startAfter) start(request.lease, false, request.result)
            else request.result.success(mapOf("state" to "permission_granted"))
        } catch (_: Exception) { pendingEnable = null; request.result.success(mapOf("state" to "unavailable")) }
    }
    fun onActivityResult(requestCode: Int) {
        if (requestCode != ENABLE_REQUEST) return
        val pending = pendingEnable ?: return; pendingEnable = null
        if (pending.lease != lease) { pending.result.success(mapOf("state" to "stopped")); return }
        try {
            if (permitted() && manager?.adapter?.isEnabled == true) finishAccess(pending)
            else { state("bluetooth_off"); pending.result.success(status()) }
        } catch (_: Exception) { state("unavailable"); pending.result.success(status()) }
    }

    private fun start(requested: String, requestPermission: Boolean, result: MethodChannel.Result) {
        if (requested != lease) { stop(); lease = requested }
        if (running) { result.success(status()); return }
        if (manager?.adapter == null) { state("unsupported"); result.success(status()); return }
        if (!permitted()) {
            state("permission_required")
            if (requestPermission) requestAccess(requested, result, true)
            else result.success(status())
            return
        }
        try {
            val adapter = manager!!.adapter
            if (!adapter.isEnabled) { state("bluetooth_off"); result.success(status()); return }
            server = manager!!.openGattServer(app, serverCallbacks)
            if (server == null) { state("unsupported"); result.success(status()); return }
            characteristic = BluetoothGattCharacteristic(CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_INDICATE,
                BluetoothGattCharacteristic.PERMISSION_WRITE).apply {
                addDescriptor(BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
            }
            val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
            service.addCharacteristic(characteristic!!)
            if (server?.addService(service) != true) { stop(); state("unavailable"); result.success(status()); return }
            running = true
            val intent = Intent(app, BluetoothMeshKeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(intent) else app.startService(intent)
            startScanning()
            state("active"); result.success(status())
        } catch (_: Exception) {
            stop(); state("unavailable"); result.success(status())
        }
    }
    fun onPermissionsResult(requestCode: Int) {
        if (requestCode != PERMISSION_REQUEST) return
        val pending = pendingPermission ?: return
        pendingPermission = null
        if (pending.lease != lease) { pending.result.success(mapOf("state" to "stopped")); return }
        if (!permitted()) { state("permission_required"); pending.result.success(status()) }
        else finishAccess(pending)
    }
    private fun startScanning() {
        val cycle = object : Runnable {
            override fun run() {
                if (!running) return
                try {
                    manager?.adapter?.bluetoothLeScanner?.startScan(
                        listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()),
                        ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build(), scanCallbacks)
                    main.postDelayed({
                        try { manager?.adapter?.bluetoothLeScanner?.stopScan(scanCallbacks) } catch (_: Exception) {}
                    }, 12000)
                    val now = SystemClock.elapsedRealtime()
                    peers.values.filter { now - it.touched > 60000 }.toList().forEach { close(it) }
                    visited.entries.removeAll { now - it.value > 300000 }
                } catch (_: Exception) { state("bluetooth_off") }
                main.postDelayed(this, 45000)
            }
        }
        scanCycle = cycle; main.post(cycle)
    }
    private val scanCallbacks = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) { main.post {
            if (!running || peers.size >= 4) return@post
            try {
                val address = result.device.address
                val now = SystemClock.elapsedRealtime()
                if (peers.values.any { it.device.address == address } || now - (visited[address] ?: -60000) < 45000) return@post
                if (visited.size >= 64) visited.remove(visited.keys.first())
                visited[address] = now
                val peer = Peer("c:$address", result.device, true); peers[peer.key] = peer
                peer.gatt = result.device.connectGatt(app, false, clientCallbacks, BluetoothDevice.TRANSPORT_LE)
                main.postDelayed({ if (!peer.ready && peers[peer.key] === peer) close(peer) }, 12000)
            } catch (_: Exception) { /* No raw hardware identifiers in logs. */ }
        } }
        override fun onScanFailed(errorCode: Int) { main.post { if (running) state("unavailable") } }
    }
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) { main.post {
            if (running) state("unsupported_peripheral") // Central connections can still exchange in both directions.
        } }
    }
    private fun ready(peer: Peer) {
        if (!running || peer.generation != lease || peer.ready) return
        peer.ready = true; peer.touched = SystemClock.elapsedRealtime()
        event(mapOf("type" to "peer", "peer" to peer.id, "connected" to true))
    }
    private fun accept(peer: Peer, bytes: ByteArray) {
        if (!running || peer.generation != lease || !peer.ready) return
        try {
            peer.touched = SystemClock.elapsedRealtime()
            val frame = peer.decoder.accept(bytes)
            if (frame != null) event(mapOf("type" to "frame", "peer" to peer.id, "data" to frame))
        } catch (_: Exception) { close(peer) }
    }
    @Suppress("DEPRECATION")
    private fun transmit(peer: Peer) {
        if (!peer.ready || peer.busy || peer.chunks.isEmpty() || peer.generation != lease) return
        val bytes = peer.chunks.first(); peer.busy = true; peer.touched = SystemClock.elapsedRealtime()
        try {
            val sent = if (peer.client) {
                val remote = peer.remote ?: return close(peer)
                remote.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT; remote.value = bytes
                peer.gatt?.writeCharacteristic(remote) == true
            } else {
                val local = characteristic ?: return close(peer)
                local.value = bytes; server?.notifyCharacteristicChanged(peer.device, local, true) == true
            }
            if (!sent) close(peer)
        } catch (_: Exception) { close(peer) }
    }
    private fun transmitted(peer: Peer, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) { close(peer); return }
        if (peer.chunks.isNotEmpty()) peer.queuedBytes -= peer.chunks.removeFirst().size
        peer.busy = false; transmit(peer)
    }
    private fun close(peer: Peer) {
        if (peers[peer.key] !== peer) return
        peers.remove(peer.key)
        if (peer.ready) event(mapOf("type" to "peer", "peer" to peer.id, "connected" to false))
        peer.ready = false; peer.decoder.reset(); peer.chunks.clear()
        try {
            if (peer.client) { peer.gatt?.disconnect(); peer.gatt?.close() }
            else server?.cancelConnection(peer.device)
        } catch (_: Exception) {}
    }
    private fun client(gatt: BluetoothGatt) = peers.values.firstOrNull { it.gatt === gatt && it.generation == lease }
    private val clientCallbacks = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) { main.post {
            val peer = client(gatt) ?: return@post
            if (status != BluetoothGatt.GATT_SUCCESS || newState == BluetoothProfile.STATE_DISCONNECTED) close(peer)
            else if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (!gatt.requestMtu(247)) gatt.discoverServices()
            }
        } }
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) { main.post {
            client(gatt)?.mtu = if (status == BluetoothGatt.GATT_SUCCESS) mtu else 23
            gatt.discoverServices()
        } }
        @Suppress("DEPRECATION")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) { main.post {
            val peer = client(gatt) ?: return@post
            val remote = gatt.getService(SERVICE_UUID)?.getCharacteristic(CHAR_UUID)
            val descriptor = remote?.getDescriptor(CCCD_UUID)
            if (status != BluetoothGatt.GATT_SUCCESS || remote == null || descriptor == null ||
                !gatt.setCharacteristicNotification(remote, true)) return@post close(peer)
            peer.remote = remote; descriptor.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            if (!gatt.writeDescriptor(descriptor)) close(peer)
        } }
        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) { main.post {
            val peer = client(gatt) ?: return@post
            if (status == BluetoothGatt.GATT_SUCCESS && descriptor.uuid == CCCD_UUID) ready(peer) else close(peer)
        } }
        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            main.post { client(gatt)?.let { transmitted(it, status) } }
        }
        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val bytes = characteristic.value?.clone() ?: return
            main.post { client(gatt)?.let { accept(it, bytes) } }
        }
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            main.post { client(gatt)?.let { accept(it, value.clone()) } }
        }
    }
    private fun peripheral(device: BluetoothDevice) = peers["s:${device.address}"]
    private val serverCallbacks = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) { main.post {
            if (!running || service.uuid != SERVICE_UUID || status != BluetoothGatt.GATT_SUCCESS) return@post
            try {
                val advertiser=manager?.adapter?.bluetoothLeAdvertiser
                if(advertiser==null) { state("unsupported_peripheral"); return@post }
                advertiser.startAdvertising(
                    AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
                        .setConnectable(true).setTimeout(0).build(),
                    AdvertiseData.Builder().addServiceUuid(ParcelUuid(SERVICE_UUID)).setIncludeDeviceName(false).build(),
                    advertiseCallback)
            } catch (_: Exception) { state("unsupported_peripheral") }
        } }
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) { main.post {
            if (!running) return@post
            val existing = peripheral(device)
            if (newState == BluetoothProfile.STATE_DISCONNECTED) { existing?.let { close(it) }; return@post }
            if (newState == BluetoothProfile.STATE_CONNECTED && existing == null) {
                if (peers.size >= 4) { server?.cancelConnection(device); return@post }
                val peer = Peer("s:${device.address}",device,false); peers[peer.key] = peer
            }
        } }
        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) { main.post { peripheral(device)?.mtu = mtu } }
        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) { main.post {
            val peer = peripheral(device)
            val valid = peer != null && descriptor.uuid == CCCD_UUID && !preparedWrite && offset == 0 &&
                value.contentEquals(BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
            if (responseNeeded) server?.sendResponse(device, requestId,
                if (valid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,0,null)
            if (valid) ready(peer!!)
        } }
        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int,
            target: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) { main.post {
            val peer = peripheral(device)
            val valid = peer?.ready == true && target.uuid == CHAR_UUID && !preparedWrite && offset == 0 && value.size in 1..512
            if (responseNeeded) server?.sendResponse(device,requestId,
                if (valid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,0,null)
            if (valid) accept(peer!!,value.clone())
        } }
        override fun onNotificationSent(device: BluetoothDevice, status: Int) { main.post {
            peripheral(device)?.let { transmitted(it,status) }
        } }
    }
    private fun stop() {
        pendingPermission?.result?.success(mapOf("state" to "stopped")); pendingPermission = null
        pendingEnable?.result?.success(mapOf("state" to "stopped")); pendingEnable = null
        running = false
        scanCycle?.let { main.removeCallbacks(it) }; scanCycle = null
        try { manager?.adapter?.bluetoothLeScanner?.stopScan(scanCallbacks) } catch (_: Exception) {}
        try { manager?.adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
        peers.values.toList().forEach { close(it) }; visited.clear()
        try { server?.clearServices(); server?.close() } catch (_: Exception) {}
        server = null; characteristic = null
        app.stopService(Intent(app, BluetoothMeshKeepAliveService::class.java))
        state("stopped")
    }
    fun dispose() {
        stop(); methods.setMethodCallHandler(null); events.setStreamHandler(null); sink = null
    }
    companion object {
        const val PERMISSION_REQUEST = 17482
        const val ENABLE_REQUEST = 17483
        val SERVICE_UUID: UUID = UUID.fromString("c358e1b0-bf5c-48ec-9f05-241f97d4a06a")
        val CHAR_UUID: UUID = UUID.fromString("c358e1b1-bf5c-48ec-9f05-241f97d4a06a")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
