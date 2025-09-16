package com.geoat.app



import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "location_validation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMockSettingEnabled" -> {
                    try {
                        val isMockEnabled = checkMockLocationSetting()
                        result.success(isMockEnabled)
                    } catch (e: Exception) {
                        result.error("MOCK_CHECK_ERROR", "Failed to check mock location setting", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkMockLocationSetting(): Boolean {
        return try {
            // Check if mock location is enabled in developer options
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // For Android 6.0 and above, this setting might not be accessible
                // due to security restrictions, so we return false as a safe default
                try {
                    val mockLocationEnabled = Settings.Secure.getInt(
                        contentResolver,
                        Settings.Secure.ALLOW_MOCK_LOCATION,
                        0
                    ) != 0
                    
                    // Log for debugging purposes
                    println("Mock location setting check: $mockLocationEnabled")
                    
                    mockLocationEnabled
                } catch (e: Settings.SettingNotFoundException) {
                    // Setting doesn't exist or is not accessible
                    println("Mock location setting not found or not accessible")
                    false
                }
            } else {
                // For older Android versions
                val mockLocationEnabled = Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0
                ) != 0
                
                println("Mock location setting check (legacy): $mockLocationEnabled")
                mockLocationEnabled
            }
        } catch (e: Exception) {
            println("Error checking mock location setting: ${e.message}")
            // Return false as safe default if we can't determine the setting
            false
        }
    }
}