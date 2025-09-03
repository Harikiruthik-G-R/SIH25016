package com.geoat.app

import android.content.Context
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import android.provider.Settings
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt as AndroidXBiometricPrompt
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import kotlin.random.Random

class BiometricPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: FragmentActivity? = null
    private var cancellationSignal: CancellationSignal? = null
    private val TAG = "BiometricPlugin"
    private val executor: Executor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "biometric_scanner")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "isScannerAvailable" -> {
                result.success(isBiometricScannerAvailable())
            }
            "initializeScanner" -> {
                result.success(initializeBiometricScanner())
            }
            "captureFingerprint" -> {
                val instruction = call.argument<String>("instruction") ?: "Place finger on scanner"
                val timeout = call.argument<Int>("timeout") ?: 30
                captureFingerprint(instruction, timeout, result)
            }
            "verifyFingerprint" -> {
                val storedTemplate = call.argument<String>("storedTemplate") ?: ""
                val capturedTemplate = call.argument<String>("capturedTemplate") ?: ""
                verifyFingerprint(storedTemplate, capturedTemplate, result)
            }
            "getDeviceId" -> {
                result.success(getDeviceId())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isBiometricScannerAvailable(): Boolean {
        return try {
            val biometricManager = BiometricManager.from(context)
            when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
                BiometricManager.BIOMETRIC_SUCCESS -> {
                    Log.d(TAG, "App can authenticate using biometrics.")
                    true
                }
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
                    Log.e(TAG, "No biometric features available on this device.")
                    false
                }
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
                    Log.e(TAG, "Biometric features are currently unavailable.")
                    false
                }
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                    Log.e(TAG, "The user hasn't associated any biometric credentials with their account.")
                    false
                }
                else -> {
                    Log.e(TAG, "Unknown biometric error.")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking biometric availability: ${e.message}")
            false
        }
    }

    private fun initializeBiometricScanner(): Boolean {
        return try {
            if (isBiometricScannerAvailable()) {
                Log.d(TAG, "Biometric scanner initialized successfully")
                true
            } else {
                Log.e(TAG, "Failed to initialize biometric scanner")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing biometric scanner: ${e.message}")
            false
        }
    }

    private fun captureFingerprint(instruction: String, timeoutSeconds: Int, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.success(mapOf(
                "success" to false,
                "error" to "Activity not available for biometric authentication"
            ))
            return
        }

        try {
            val biometricPrompt = AndroidXBiometricPrompt(
                currentActivity as androidx.fragment.app.FragmentActivity,
                executor,
                object : AndroidXBiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        super.onAuthenticationError(errorCode, errString)
                        Log.e(TAG, "Authentication error: $errString")
                        result.success(mapOf(
                            "success" to false,
                            "error" to "Authentication error: $errString"
                        ))
                    }

                    override fun onAuthenticationSucceeded(authResult: AndroidXBiometricPrompt.AuthenticationResult) {
                        super.onAuthenticationSucceeded(authResult)
                        Log.d(TAG, "Authentication succeeded")
                        
                        // Generate fingerprint template and data
                        val fingerprintData = generateFingerprintData()
                        val template = generateFingerprintTemplate(fingerprintData)
                        val quality = generateQualityScore()
                        
                        result.success(mapOf(
                            "success" to true,
                            "fingerprintData" to fingerprintData,
                            "template" to template,
                            "quality" to quality,
                            "error" to null
                        ))
                    }

                    override fun onAuthenticationFailed() {
                        super.onAuthenticationFailed()
                        Log.w(TAG, "Authentication failed")
                        result.success(mapOf(
                            "success" to false,
                            "error" to "Fingerprint not recognized. Please try again."
                        ))
                    }
                }
            )

            val promptInfo = AndroidXBiometricPrompt.PromptInfo.Builder()
                .setTitle("Fingerprint Registration")
                .setSubtitle(instruction)
                .setDescription("Place your finger on the fingerprint sensor")
                .setNegativeButtonText("Cancel")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK)
                .build()

            biometricPrompt.authenticate(promptInfo)

        } catch (e: Exception) {
            Log.e(TAG, "Error capturing fingerprint: ${e.message}")
            result.success(mapOf(
                "success" to false,
                "error" to "Error capturing fingerprint: ${e.message}"
            ))
        }
    }

    private fun verifyFingerprint(storedTemplate: String, capturedTemplate: String, result: Result) {
        try {
            // Simple template comparison for demonstration
            // In a real implementation, you would use more sophisticated matching algorithms
            val similarity = calculateTemplateSimilarity(storedTemplate, capturedTemplate)
            val threshold = 0.8 // 80% similarity threshold
            val isMatch = similarity >= threshold
            
            Log.d(TAG, "Template verification - Similarity: $similarity, Match: $isMatch")
            
            result.success(mapOf(
                "isMatch" to isMatch,
                "confidence" to similarity,
                "error" to null
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error verifying fingerprint: ${e.message}")
            result.success(mapOf(
                "isMatch" to false,
                "confidence" to 0.0,
                "error" to "Verification failed: ${e.message}"
            ))
        }
    }

    private fun generateFingerprintData(): String {
        try {
            // Generate mock fingerprint data (base64 encoded)
            val deviceId = getDeviceId()
            val timestamp = System.currentTimeMillis().toString()
            val randomData = generateSecureRandom(32)
            val combinedData = "$deviceId-$timestamp-$randomData"
            
            return Base64.encodeToString(
                combinedData.toByteArray(StandardCharsets.UTF_8),
                Base64.DEFAULT
            ).trim()
        } catch (e: Exception) {
            Log.e(TAG, "Error generating fingerprint data: ${e.message}")
            return Base64.encodeToString(
                "mock_fingerprint_data_${System.currentTimeMillis()}".toByteArray(),
                Base64.DEFAULT
            ).trim()
        }
    }

    private fun generateFingerprintTemplate(fingerprintData: String): String {
        return try {
            // Create SHA-256 hash of fingerprint data as template
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(fingerprintData.toByteArray(StandardCharsets.UTF_8))
            
            // Convert to hex string
            hashBytes.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error generating template: ${e.message}")
            // Fallback template
            val fallbackData = "template_${System.currentTimeMillis()}_${Random.nextInt(10000)}"
            MessageDigest.getInstance("SHA-256")
                .digest(fallbackData.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }

    private fun generateQualityScore(): Int {
        // Generate a realistic quality score between 60-95
        return (60..95).random()
    }

    private fun calculateTemplateSimilarity(template1: String, template2: String): Double {
        if (template1.isEmpty() || template2.isEmpty()) return 0.0
        
        return try {
            // Simple similarity calculation based on string comparison
            // In production, use proper biometric template matching algorithms
            if (template1 == template2) {
                1.0 // Perfect match
            } else {
                // Calculate Levenshtein distance-based similarity
                val maxLength = maxOf(template1.length, template2.length)
                val distance = levenshteinDistance(template1, template2)
                val similarity = 1.0 - (distance.toDouble() / maxLength)
                maxOf(0.0, similarity) // Ensure non-negative
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating similarity: ${e.message}")
            0.0
        }
    }

    private fun levenshteinDistance(s1: String, s2: String): Int {
        val len1 = s1.length
        val len2 = s2.length
        val dp = Array(len1 + 1) { IntArray(len2 + 1) }

        for (i in 0..len1) {
            dp[i][0] = i
        }
        for (j in 0..len2) {
            dp[0][j] = j
        }

        for (i in 1..len1) {
            for (j in 1..len2) {
                val cost = if (s1[i - 1] == s2[j - 1]) 0 else 1
                dp[i][j] = minOf(
                    dp[i - 1][j] + 1,      // deletion
                    dp[i][j - 1] + 1,      // insertion
                    dp[i - 1][j - 1] + cost // substitution
                )
            }
        }
        return dp[len1][len2]
    }

    private fun generateSecureRandom(length: Int): String {
        val secureRandom = SecureRandom()
        val randomBytes = ByteArray(length)
        secureRandom.nextBytes(randomBytes)
        return Base64.encodeToString(randomBytes, Base64.DEFAULT).trim()
    }

    private fun getDeviceId(): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                ?: "unknown_device_${System.currentTimeMillis()}"
        } catch (e: Exception) {
            Log.e(TAG, "Error getting device ID: ${e.message}")
            "fallback_device_${System.currentTimeMillis()}"
        }
    }
}