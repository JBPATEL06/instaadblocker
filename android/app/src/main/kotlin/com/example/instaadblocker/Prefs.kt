package com.example.instaadblocker

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList

object Prefs {
    private const val PREFS_NAME = "instaadblocker_prefs"

    // Master switch
    private const val KEY_ENABLED = "key_enabled"
    private const val KEY_SKIP_COUNT = "key_skip_count"
    private const val KEY_COOLDOWN_MS = "key_cooldown_ms"
    private const val KEY_BLOCK_ACTION = "key_block_action" // "back" or "skip"

    // Individual app toggles
    private const val KEY_INSTAGRAM_ADS = "key_instagram_ads"
    private const val KEY_INSTAGRAM_REELS = "key_instagram_reels_blocked"
    private const val KEY_YOUTUBE_SHORTS = "key_youtube_shorts"
    private const val KEY_SNAPCHAT_SPOTLIGHT = "key_snapchat_spotlight"
    private const val KEY_FACEBOOK_REELS = "key_facebook_reels"
    private const val KEY_TIKTOK = "key_tiktok"
    private const val KEY_REDDIT_SHORTS = "key_reddit_shorts"
    private const val KEY_X_SHORTS = "key_x_shorts"

    // Mindful Break feature
    private const val KEY_BREAK_UNTIL = "key_break_until_timestamp"

    private val logBuffer = CopyOnWriteArrayList<String>()
    private const val MAX_LOGS = 100
    private val timeFormat = SimpleDateFormat("HH:mm:ss.SSS", Locale.getDefault())

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // Break
    fun setBreakDuration(context: Context, minutes: Int) {
        val until = if (minutes > 0) System.currentTimeMillis() + (minutes * 60 * 1000L) else 0L
        getPrefs(context).edit().putLong(KEY_BREAK_UNTIL, until).apply()
        if (minutes > 0) {
            addLog("Break started for $minutes min (Shield paused)")
        } else {
            addLog("Break ended. Shield resumed.")
        }
    }

    fun cancelBreak(context: Context) {
        getPrefs(context).edit().putLong(KEY_BREAK_UNTIL, 0L).apply()
        addLog("Break cancelled. Shield resumed.")
    }

    fun isBreakActive(context: Context): Boolean {
        val until = getPrefs(context).getLong(KEY_BREAK_UNTIL, 0L)
        if (until <= 0L) return false
        val now = System.currentTimeMillis()
        if (now < until) {
            return true
        }
        // Expired
        getPrefs(context).edit().putLong(KEY_BREAK_UNTIL, 0L).apply()
        addLog("Break duration expired. Shield automatically resumed!")
        return false
    }

    fun getRemainingBreakSeconds(context: Context): Long {
        val until = getPrefs(context).getLong(KEY_BREAK_UNTIL, 0L)
        if (until <= 0L) return 0L
        val diff = until - System.currentTimeMillis()
        return if (diff > 0L) diff / 1000L else 0L
    }

    // Master
    fun isEnabled(context: Context): Boolean = getPrefs(context).getBoolean(KEY_ENABLED, true)
    fun setEnabled(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
        addLog("Master switch: " + if (enabled) "ENABLED" else "DISABLED")
    }

    // Skip count
    fun getSkipCount(context: Context): Int = getPrefs(context).getInt(KEY_SKIP_COUNT, 0)
    fun incrementSkipCount(context: Context): Int {
        val prefs = getPrefs(context)
        val newCount = prefs.getInt(KEY_SKIP_COUNT, 0) + 1
        prefs.edit().putInt(KEY_SKIP_COUNT, newCount).apply()
        return newCount
    }
    fun resetSkipCount(context: Context) {
        getPrefs(context).edit().putInt(KEY_SKIP_COUNT, 0).apply()
        addLog("Counter reset to 0")
    }

    // Cooldown
    fun getCooldownMs(context: Context): Long = getPrefs(context).getLong(KEY_COOLDOWN_MS, 600L)
    fun setCooldownMs(context: Context, cooldown: Long) {
        getPrefs(context).edit().putLong(KEY_COOLDOWN_MS, cooldown).apply()
    }

    // Block action ("back" to exit, or "skip" to swipe up)
    fun getBlockAction(context: Context): String = getPrefs(context).getString(KEY_BLOCK_ACTION, "back") ?: "back"
    fun setBlockAction(context: Context, action: String) {
        getPrefs(context).edit().putString(KEY_BLOCK_ACTION, action).apply()
        addLog("Block action set to: $action")
    }

    // Instagram
    fun isInstagramAdsEnabled(context: Context): Boolean = getPrefs(context).getBoolean(KEY_INSTAGRAM_ADS, true)
    fun setInstagramAdsEnabled(context: Context, enabled: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_INSTAGRAM_ADS, enabled).apply()

    fun isInstagramReelsBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_INSTAGRAM_REELS, true)
    fun setInstagramReelsBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_INSTAGRAM_REELS, blocked).apply()

    // YouTube Shorts
    fun isYouTubeShortsBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_YOUTUBE_SHORTS, true)
    fun setYouTubeShortsBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_YOUTUBE_SHORTS, blocked).apply()

    // Snapchat Spotlight
    fun isSnapchatSpotlightBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_SNAPCHAT_SPOTLIGHT, true)
    fun setSnapchatSpotlightBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_SNAPCHAT_SPOTLIGHT, blocked).apply()

    // Facebook Reels
    fun isFacebookReelsBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_FACEBOOK_REELS, true)
    fun setFacebookReelsBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_FACEBOOK_REELS, blocked).apply()

    // TikTok
    fun isTikTokBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_TIKTOK, false)
    fun setTikTokBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_TIKTOK, blocked).apply()

    // Reddit
    fun isRedditShortsBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_REDDIT_SHORTS, false)
    fun setRedditShortsBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_REDDIT_SHORTS, blocked).apply()

    // X (Twitter)
    fun isXShortsBlocked(context: Context): Boolean = getPrefs(context).getBoolean(KEY_X_SHORTS, false)
    fun setXShortsBlocked(context: Context, blocked: Boolean) =
        getPrefs(context).edit().putBoolean(KEY_X_SHORTS, blocked).apply()

    // Logging
    fun addLog(msg: String) {
        val entry = "[${timeFormat.format(Date())}] $msg"
        logBuffer.add(0, entry)
        if (logBuffer.size > MAX_LOGS) {
            logBuffer.removeAt(logBuffer.lastIndex)
        }
    }

    fun getLogs(): List<String> = logBuffer.toList()
    fun clearLogs() = logBuffer.clear()
}
