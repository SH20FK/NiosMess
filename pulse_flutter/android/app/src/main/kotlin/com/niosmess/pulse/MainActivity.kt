package com.niosmess.pulse

import android.app.ActivityManager
import android.content.Intent
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val SECURITY_CHANNEL = "com.niosmess.pulse/security"
    private val SYSTEM_CHANNEL = "app.niosmess/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureFlag" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BATTERY_OPT_ERROR", e.message, null)
                    }
                }
                "getHardwareSpecs" -> {
                    try {
                        val specs = mutableMapOf<String, Any?>()

                        // 1. Manufacturer & Model
                        specs["manufacturer"] = Build.MANUFACTURER
                        specs["brand"] = Build.BRAND
                        specs["model"] = Build.MODEL
                        specs["device"] = Build.DEVICE
                        specs["board"] = Build.BOARD
                        specs["hardware"] = Build.HARDWARE

                        // 2. SoC / Processor
                        var socModel = ""
                        var socManufacturer = ""
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                socModel = Build.SOC_MODEL
                                socManufacturer = Build.SOC_MANUFACTURER
                            } catch (_: Exception) {}
                        }
                        if (socModel.isEmpty()) {
                            try {
                                val cpuInfo = java.io.File("/proc/cpuinfo").readLines()
                                for (line in cpuInfo) {
                                    if (line.startsWith("Hardware") || line.startsWith("model name")) {
                                        val parts = line.split(":")
                                        if (parts.size > 1) {
                                            socModel = parts[1].trim()
                                            break
                                        }
                                    }
                                }
                            } catch (_: Exception) {}
                        }
                        if (socModel.isEmpty()) {
                            socModel = Build.HARDWARE
                        }
                        specs["socModel"] = socModel
                        specs["socManufacturer"] = socManufacturer
                        specs["cpuCores"] = Runtime.getRuntime().availableProcessors()
                        specs["supportedAbis"] = Build.SUPPORTED_ABIS.toList()

                        // 3. Display
                        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                        val displayMetrics = resources.displayMetrics
                        val widthPx: Int
                        val heightPx: Int
                        val refreshRate: Float
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val windowMetrics = wm.currentWindowMetrics
                            val bounds = windowMetrics.bounds
                            widthPx = bounds.width()
                            heightPx = bounds.height()
                            refreshRate = display?.refreshRate ?: 60f
                        } else {
                            widthPx = displayMetrics.widthPixels
                            heightPx = displayMetrics.heightPixels
                            @Suppress("DEPRECATION")
                            refreshRate = wm.defaultDisplay.refreshRate
                        }
                        specs["screenWidthPx"] = widthPx
                        specs["screenHeightPx"] = heightPx
                        specs["densityDpi"] = displayMetrics.densityDpi
                        specs["density"] = displayMetrics.density
                        specs["refreshRate"] = refreshRate

                        // 4. Memory (RAM)
                        val actManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        actManager.getMemoryInfo(memInfo)
                        specs["totalRamBytes"] = memInfo.totalMem
                        specs["availRamBytes"] = memInfo.availMem
                        specs["lowMemory"] = memInfo.lowMemory

                        // 5. Storage (Internal)
                        try {
                            val dataDir = Environment.getDataDirectory()
                            val statFs = StatFs(dataDir.path)
                            val blockSize = statFs.blockSizeLong
                            specs["totalStorageBytes"] = statFs.blockCountLong * blockSize
                            specs["freeStorageBytes"] = statFs.availableBlocksLong * blockSize
                        } catch (_: Exception) {}

                        // 6. Cameras
                        try {
                            val cameraManager = getSystemService(CAMERA_SERVICE) as? CameraManager
                            if (cameraManager != null) {
                                val cameraList = mutableListOf<Map<String, Any?>>()
                                for (id in cameraManager.cameraIdList) {
                                    try {
                                        val chars = cameraManager.getCameraCharacteristics(id)
                                        val facing = chars.get(CameraCharacteristics.LENS_FACING)
                                        val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                                        val sizes = map?.getOutputSizes(ImageFormat.JPEG)
                                        var maxMp = 0f
                                        if (sizes != null && sizes.isNotEmpty()) {
                                            val largest = sizes.maxByOrNull { it.width * it.height }
                                            if (largest != null) {
                                                maxMp = (largest.width * largest.height) / 1_000_000f
                                            }
                                        }
                                        cameraList.add(mapOf(
                                            "id" to id,
                                            "facing" to if (facing == CameraCharacteristics.LENS_FACING_FRONT) "front" else "back",
                                            "maxMegapixels" to maxMp
                                        ))
                                    } catch (_: Exception) {}
                                }
                                specs["cameras"] = cameraList
                            }
                        } catch (_: Exception) {}

                        // 7. OS & System
                        specs["osVersion"] = Build.VERSION.RELEASE
                        specs["sdkInt"] = Build.VERSION.SDK_INT
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            specs["securityPatch"] = Build.VERSION.SECURITY_PATCH
                        }
                        specs["buildId"] = Build.DISPLAY

                        result.success(specs)
                    } catch (e: Exception) {
                        result.error("HARDWARE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val params = window.attributes
            params.preferredRefreshRate = 144f
            window.attributes = params
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            )
        }
    }
}
