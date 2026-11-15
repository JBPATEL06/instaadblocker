package com.example.instaadblocker

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "adskip/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                "isServiceEnabled" -> {
                    val enabled = isAccessibilityServiceEnabled()
                    result.success(enabled)
                }

                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    Prefs.setEnabled(this, enabled)
                    result.success(true)
                }

                "getEnabled" -> {
                    result.success(Prefs.isEnabled(this))
                }

                "getCount" -> {
                    result.success(Prefs.getSkipCount(this))
                }

                "resetCount" -> {
                    Prefs.resetSkipCount(this)
                    result.success(true)
                }

                // Per-App Settings Map
                "getAllSettings" -> {
                    val settings = mapOf(
                        "master" to Prefs.isEnabled(this),
                        "blockAction" to Prefs.getBlockAction(this),
                        "cooldownMs" to Prefs.getCooldownMs(this).toInt(),
                        "instagramAds" to Prefs.isInstagramAdsEnabled(this),
                        "instagramReels" to Prefs.isInstagramReelsBlocked(this),
                        "youtubeShorts" to Prefs.isYouTubeShortsBlocked(this),
                        "snapchatSpotlight" to Prefs.isSnapchatSpotlightBlocked(this),
                        "facebookReels" to Prefs.isFacebookReelsBlocked(this),
                        "tiktok" to Prefs.isTikTokBlocked(this),
                        "redditShorts" to Prefs.isRedditShortsBlocked(this),
                        "xShorts" to Prefs.isXShortsBlocked(this),
                        "isBreakActive" to Prefs.isBreakActive(this),
                        "remainingBreakSeconds" to Prefs.getRemainingBreakSeconds(this)
                    )
                    result.success(settings)
                }

                "startBreak" -> {
                    val minutes = call.argument<Int>("minutes") ?: 5
                    Prefs.setBreakDuration(this, minutes)
                    result.success(true)
                }

                "cancelBreak" -> {
                    Prefs.cancelBreak(this)
                    result.success(true)
                }

                "getBreakStatus" -> {
                    val status = mapOf(
                        "isBreakActive" to Prefs.isBreakActive(this),
                        "remainingSeconds" to Prefs.getRemainingBreakSeconds(this)
                    )
                    result.success(status)
                }

                "setSetting" -> {
                    val key = call.argument<String>("key") ?: ""
                    when (key) {
                        "blockAction" -> {
                            val action = call.argument<String>("value") ?: "back"
                            Prefs.setBlockAction(this, action)
                        }
                        "cooldownMs" -> {
                            val cd = (call.argument<Int>("value") ?: 600).toLong()
                            Prefs.setCooldownMs(this, cd)
                        }
                        "instagramAds" -> Prefs.setInstagramAdsEnabled(this, call.argument<Boolean>("value") ?: true)
                        "instagramReels" -> Prefs.setInstagramReelsBlocked(this, call.argument<Boolean>("value") ?: false)
                        "youtubeShorts" -> Prefs.setYouTubeShortsBlocked(this, call.argument<Boolean>("value") ?: true)
                        "snapchatSpotlight" -> Prefs.setSnapchatSpotlightBlocked(this, call.argument<Boolean>("value") ?: true)
                        "facebookReels" -> Prefs.setFacebookReelsBlocked(this, call.argument<Boolean>("value") ?: true)
                        "tiktok" -> Prefs.setTikTokBlocked(this, call.argument<Boolean>("value") ?: false)
                        "redditShorts" -> Prefs.setRedditShortsBlocked(this, call.argument<Boolean>("value") ?: false)
                        "xShorts" -> Prefs.setXShortsBlocked(this, call.argument<Boolean>("value") ?: false)
                    }
                    result.success(true)
                }

                "getRecentLogs" -> {
                    result.success(Prefs.getLogs())
                }

                "clearLogs" -> {
                    Prefs.clearLogs()
                    result.success(true)
                }

                "triggerDump" -> {
                    val activeService = AdSkipService.instance
                    if (activeService != null) {
                        val dump = activeService.dumpCurrentHierarchy()
                        result.success(dump)
                    } else {
                        result.success("AdSkipService is not active. Please ensure Accessibility Service is turned ON.")
                    }
                }

                "openApp" -> {
                    val pkg = call.argument<String>("package") ?: "com.instagram.android"
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.error("NOT_INSTALLED", "App is not installed on this device.", null)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", e.localizedMessage, null)
                    }
                }

                "openInstagram" -> {
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage("com.instagram.android")
                        if (launchIntent != null) {
                            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.error("NOT_INSTALLED", "Instagram is not installed on this device.", null)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", e.localizedMessage, null)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent().apply {
                                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                                val packageName = packageName
                                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                    data = Uri.parse("package:$packageName")
                                } else {
                                    action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                                }
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("BATTERY_ERROR", e2.localizedMessage, null)
                        }
                    }
                }

                "openAutostartSettings" -> {
                    try {
                        val miuiIntent = Intent().apply {
                            component = android.content.ComponentName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity"
                            )
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(miuiIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val detailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(detailsIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("AUTOSTART_ERROR", e2.localizedMessage, null)
                        }
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        if (AdSkipService.isRunning()) {
            return true
        }

        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        val expectedServiceName = "${packageName}/${AdSkipService::class.java.canonicalName}"
        val shortServiceName = "${packageName}/.AdSkipService"

        for (service in enabledServices) {
            val id = service.id
            if (id.equals(expectedServiceName, ignoreCase = true) || id.equals(shortServiceName, ignoreCase = true)) {
                return true
            }
        }

        try {
            val settingValue = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            return settingValue.contains(packageName)
        } catch (e: Exception) {
            return false
        }
    }
}
