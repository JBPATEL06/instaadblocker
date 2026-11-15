@file:Suppress("DEPRECATION")
package com.example.instaadblocker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

class AdSkipService : AccessibilityService() {

    companion object {
        private const val TAG = "IGDUMP"
        @Volatile
        var instance: AdSkipService? = null
            private set

        fun isRunning(): Boolean = instance != null

        // Supported short-form video app packages
        private val SUPPORTED_PACKAGES = setOf(
            "com.instagram.android",
            "com.instagram.lite",
            "com.google.android.youtube",
            "com.google.android.apps.youtube.mango",
            "com.snapchat.android",
            "com.facebook.katana",
            "com.facebook.lite",
            "com.zhiliaoapp.musically",
            "com.ss.android.ugc.trill",
            "com.reddit.frontpage",
            "com.twitter.android"
        )

        // Exact match ad labels (Instagram Reels Ad disclosures)
        private val EXACT_AD_LABELS = setOf(
            "ad",
            "sponsored",
            "sponsored ·",
            "paid partnership",
            "promoted",
            "विज्ञापन",   // Hindi for Ad
            "प्रायोजित"   // Hindi for Sponsored
        )

        // Substrings that always signify an advertisement
        private val SUBSTRING_AD_MARKERS = listOf(
            "sponsored",
            "paid partnership"
        )

        // CTA conversion buttons in ads
        private val CTA_BUTTON_KEYWORDS = setOf(
            "sign up",
            "learn more",
            "shop now",
            "install now",
            "book now",
            "apply now",
            "download",
            "order now",
            "get offer",
            "get quote",
            "watch more",
            "contact us",
            "open link",
            "play game"
        )
    }

    private var lastSkipTime = 0L
    private var lastCheckTime = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Prefs.addLog("Shield active across all short-form platforms")
        Log.d(TAG, "AdSkipService connected and listening for events across all apps")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: ""
        if (!SUPPORTED_PACKAGES.contains(pkg)) return

        val now = System.currentTimeMillis()
        val cooldown = Prefs.getCooldownMs(this)

        if (now - lastSkipTime < cooldown) return

        // Throttle rapid window changes to save CPU
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            if (now - lastCheckTime < 80) return
        }
        lastCheckTime = now

        if (!Prefs.isEnabled(this)) return

        // Mindful Break check: If user requested a break, pause blocking completely
        if (Prefs.isBreakActive(this)) {
            Log.d(TAG, "Shield currently paused due to active Mindful Break")
            return
        }

        val root = rootInActiveWindow ?: findApplicationRoot() ?: return

        try {
            when {
                // 1. INSTAGRAM
                pkg.startsWith("com.instagram") -> {
                    if (Prefs.isInstagramReelsBlocked(this) && isInstagramReelActive(root)) {
                        safeDismissShort(
                            "Instagram Reel",
                            pkg,
                            root,
                            safeViewIds = listOf("feed_tab", "home_tab"),
                            safeTabKeywords = listOf("Home", "Feed")
                        )
                        return
                    }
                    if (Prefs.isInstagramAdsEnabled(this)) {
                        val adResult = detectInstagramAd(root)
                        if (adResult.isAd) {
                            Prefs.addLog("Instagram ad [${adResult.matchedKeyword}] -> Skipped!")
                            Log.i(TAG, "Instagram ad matched: '${adResult.matchedKeyword}'")
                            performSwipeUp()
                        }
                    }
                }

                // 2. YOUTUBE SHORTS
                pkg.startsWith("com.google.android.youtube") -> {
                    if (Prefs.isYouTubeShortsBlocked(this) && isYouTubeShortsActive(root)) {
                        safeDismissShort(
                            "YouTube Shorts",
                            pkg,
                            root,
                            safeViewIds = listOf("pivot_bar", "home"),
                            safeTabKeywords = listOf("Home")
                        )
                    }
                }

                // 3. SNAPCHAT SPOTLIGHT
                pkg == "com.snapchat.android" -> {
                    if (Prefs.isSnapchatSpotlightBlocked(this) && isSnapchatSpotlightActive(root)) {
                        safeDismissShort(
                            "Snapchat Spotlight",
                            pkg,
                            root,
                            safeViewIds = listOf("chat_tab", "camera_tab"),
                            safeTabKeywords = listOf("Chat", "Camera", "Stories")
                        )
                    }
                }

                // 4. FACEBOOK REELS
                pkg.startsWith("com.facebook") -> {
                    if (Prefs.isFacebookReelsBlocked(this) && isFacebookReelsActive(root)) {
                        safeDismissShort(
                            "Facebook Reel",
                            pkg,
                            root,
                            safeViewIds = listOf("news_feed", "feed_tab"),
                            safeTabKeywords = listOf("Home", "News Feed")
                        )
                    }
                }

                // 5. TIKTOK
                pkg.contains("musically") || pkg.contains("trill") -> {
                    if (Prefs.isTikTokBlocked(this) && isTikTokActive(root)) {
                        safeDismissShort("TikTok Video", pkg, root)
                    }
                }

                // 6. REDDIT
                pkg == "com.reddit.frontpage" -> {
                    if (Prefs.isRedditShortsBlocked(this) && isRedditShortsActive(root)) {
                        safeDismissShort(
                            "Reddit Short Video",
                            pkg,
                            root,
                            safeViewIds = listOf("home_tab"),
                            safeTabKeywords = listOf("Home", "Popular", "Latest")
                        )
                    }
                }

                // 7. X (TWITTER)
                pkg == "com.twitter.android" -> {
                    if (Prefs.isXShortsBlocked(this) && isXShortsActive(root)) {
                        safeDismissShort(
                            "X Video Feed",
                            pkg,
                            root,
                            safeViewIds = listOf("timeline_tab", "home_tab"),
                            safeTabKeywords = listOf("Home", "Timeline")
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error evaluating accessibility tree: ${e.message}", e)
        }
    }

    /**
     * Executes smart, safe intervention so short-form players are exited/redirected
     * to the Home/Feed without abruptly terminating or closing the host app.
     */
    private fun safeDismissShort(
        platformName: String,
        pkg: String,
        root: AccessibilityNodeInfo,
        safeViewIds: List<String> = emptyList(),
        safeTabKeywords: List<String> = emptyList()
    ) {
        val now = System.currentTimeMillis()
        val cooldown = Prefs.getCooldownMs(this)
        if (now - lastSkipTime < cooldown) return
        lastSkipTime = now

        // SAFETY: If the user is ALREADY on the Home feed, NEVER click Home or dispatch events
        // because clicking Home on an active feed triggers a scroll-to-top and feed reload!
        if (isHomeAlreadyActive(root)) {
            Log.d(TAG, "Already on Home feed for $platformName - suppressing Home click to prevent feed reload")
            return
        }

        val action = Prefs.getBlockAction(this)
        if (action == "back") {
            // 1. First priority: Try redirecting to a safe tab (e.g. Home, Feed, Chat)
            val redirected = tryClickHomeTab(root, safeViewIds, safeTabKeywords)
            if (redirected) {
                val newCount = Prefs.incrementSkipCount(this)
                Prefs.addLog("Blocked $platformName -> Moved to Home tab! (Total: $newCount)")
                Log.d(TAG, "Moved $platformName to Home tab")
                return
            }

            // 2. Second priority: Try clicking in-app back/close arrow button inside fullscreen player
            val clickedBack = tryClickInAppBackButton(root)
            if (clickedBack) {
                val newCount = Prefs.incrementSkipCount(this)
                Prefs.addLog("Blocked $platformName -> Exited player to feed! (Total: $newCount)")
                Log.d(TAG, "Exited $platformName via in-app back button")
                return
            }

            // 3. Fallback: Global Back Action
            performGlobalAction(GLOBAL_ACTION_BACK)
            val newCount = Prefs.incrementSkipCount(this)
            Prefs.addLog("Blocked $platformName -> Exited via Back! (Total: $newCount)")
            Log.d(TAG, "Dismissed $platformName via GLOBAL_ACTION_BACK")
        } else {
            // Auto-skip mode: fast-forward past the short
            performSwipeUp()
            val newCount = Prefs.incrementSkipCount(this)
            Prefs.addLog("Blocked $platformName -> Swiped next! (Total: $newCount)")
            Log.d(TAG, "Dismissed $platformName by swiping up")
        }
    }

    /**
     * Checks if the active window is already on the Home feed so we NEVER trigger
     * a duplicate click that would reload or refresh the user's feed.
     */
    private fun isHomeAlreadyActive(root: AccessibilityNodeInfo): Boolean {
        var isHome = false
        fun search(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 25 || isHome) return

            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""

            // Instagram Home feed indicators
            if (viewId.contains("feed_tab") && node.isSelected) {
                isHome = true
                return
            }
            if (viewId.contains("action_bar_large_title") || viewId.contains("action_bar_inbox_button") || viewId.contains("stories_tray")) {
                isHome = true
                return
            }

            // YouTube Home feed indicators
            if ((desc.equals("Home", ignoreCase = true) || desc.startsWith("Home, selected", ignoreCase = true)) && node.isSelected) {
                isHome = true
                return
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    search(child, depth + 1)
                    if (isHome) return
                }
            }
        }
        search(root, 0)
        return isHome
    }

    /**
     * Finds and clicks a safe navigation tab (like "Home" or "Feed") by viewId or keywords
     * to redirect the user cleanly back to normal browsing instead of closing the application.
     */
    private fun tryClickHomeTab(
        root: AccessibilityNodeInfo,
        safeViewIds: List<String>,
        keywords: List<String>
    ): Boolean {
        var clicked = false
        fun search(node: AccessibilityNodeInfo?, depth: Int): Boolean {
            if (node == null || depth > 25 || clicked) return false

            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val text = node.text?.toString()?.trim() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            // 1. Check exact/partial resource IDs (e.g. "feed_tab", "home_tab")
            for (idKeyword in safeViewIds) {
                if (viewId.contains(idKeyword.lowercase())) {
                    var target: AccessibilityNodeInfo? = node
                    while (target != null && !target.isClickable) {
                        target = target.parent
                    }
                    if (target != null && target.isClickable) {
                        clicked = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        if (clicked) return true
                    }
                }
            }

            // 2. Check keywords (contentDescription / text)
            for (kw in keywords) {
                val matchDesc = desc.equals(kw, ignoreCase = true) ||
                        desc.startsWith("$kw, ", ignoreCase = true) ||
                        desc.startsWith("$kw tab", ignoreCase = true)
                val matchText = text.equals(kw, ignoreCase = true)
                val matchId = viewId.endsWith("${kw.lowercase()}_tab") ||
                        viewId.endsWith("tab_${kw.lowercase()}") ||
                        viewId.endsWith("tab_bar_${kw.lowercase()}")

                if (matchDesc || matchText || matchId) {
                    var target: AccessibilityNodeInfo? = node
                    while (target != null && !target.isClickable) {
                        target = target.parent
                    }
                    if (target != null && target.isClickable) {
                        clicked = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        if (clicked) return true
                    }
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    if (search(child, depth + 1)) return true
                }
            }
            return false
        }
        search(root, 0)
        return clicked
    }

    /**
     * Finds and clicks in-app back/close button inside fullscreen players.
     */
    private fun tryClickInAppBackButton(root: AccessibilityNodeInfo): Boolean {
        var clicked = false
        fun search(node: AccessibilityNodeInfo?, depth: Int): Boolean {
            if (node == null || depth > 25 || clicked) return false

            val desc = node.contentDescription?.toString()?.trim()?.lowercase() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            val isBackButton = desc == "navigate up" || desc == "back" || desc == "close" ||
                    desc == "dismiss" || desc == "collapse" ||
                    viewId.endsWith("back_button") || viewId.endsWith("up_button") ||
                    viewId.endsWith("action_bar_button_back") || viewId.endsWith("close_button") ||
                    viewId.endsWith("btn_back")

            if (isBackButton) {
                var target: AccessibilityNodeInfo? = node
                while (target != null && !target.isClickable) {
                    target = target.parent
                }
                if (target != null && target.isClickable) {
                    clicked = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    if (clicked) return true
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    if (search(child, depth + 1)) return true
                }
            }
            return false
        }
        search(root, 0)
        return clicked
    }

    private fun findApplicationRoot(): AccessibilityNodeInfo? {
        try {
            val appWindow = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_APPLICATION }
            return appWindow?.root
        } catch (e: Exception) {
            return null
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "AdSkipService onTaskRemoved - keeping background service active")
    }

    override fun onInterrupt() {
        Log.w(TAG, "AdSkipService interrupted")
        Prefs.addLog("Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
        Prefs.addLog("Service destroyed")
    }

    // ==========================================
    // 📸 INSTAGRAM DETECTION
    // ==========================================
    data class AdDetectionResult(
        val isAd: Boolean,
        val matchedKeyword: String = "",
        val nodeInfo: String = "",
        val bounds: Rect = Rect()
    )

    private fun detectInstagramAd(root: AccessibilityNodeInfo): AdDetectionResult {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        val screenWidth = displayMetrics.widthPixels

        var sponsoredFound = false
        var sponsoredKeyword = ""
        var adNodeSummary = ""
        val adBounds = Rect()

        fun search(node: AccessibilityNodeInfo?, depth: Int): Boolean {
            if (node == null || depth > 35) return false

            val rawText = node.text?.toString() ?: ""
            val rawDesc = node.contentDescription?.toString() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            val cleanText = rawText.trim().lowercase()
                .replace("›", "").replace(">", "").replace("»", "").replace("→", "").trim()

            val cleanDesc = rawDesc.trim().lowercase()
                .replace("›", "").replace(">", "").replace("»", "").replace("→", "").trim()

            val bounds = Rect()
            node.getBoundsInScreen(bounds)

            val isVisible = (bounds.bottom > 0 && bounds.top < screenHeight && bounds.right > 0 && bounds.left < screenWidth && bounds.width() > 0 && bounds.height() > 0)

            if (isVisible) {
                // Exact label ("Ad", "Sponsored")
                if (EXACT_AD_LABELS.contains(cleanText) || EXACT_AD_LABELS.contains(cleanDesc)) {
                    val matched = if (EXACT_AD_LABELS.contains(cleanText)) cleanText else cleanDesc
                    sponsoredFound = true
                    sponsoredKeyword = "Exact: '$matched'"
                    adNodeSummary = "text='$rawText', desc='$rawDesc', id='$viewId'"
                    adBounds.set(bounds)
                    return true
                }

                // Substring
                for (marker in SUBSTRING_AD_MARKERS) {
                    if (cleanText.contains(marker) || cleanDesc.contains(marker)) {
                        sponsoredFound = true
                        sponsoredKeyword = "Substring: '$marker'"
                        adNodeSummary = "text='$rawText', desc='$rawDesc', id='$viewId'"
                        adBounds.set(bounds)
                        return true
                    }
                }

                // CTA Action Buttons
                if (CTA_BUTTON_KEYWORDS.contains(cleanText) || CTA_BUTTON_KEYWORDS.contains(cleanDesc)) {
                    val matched = if (CTA_BUTTON_KEYWORDS.contains(cleanText)) cleanText else cleanDesc
                    sponsoredFound = true
                    sponsoredKeyword = "CTA Button: '$matched'"
                    adNodeSummary = "text='$rawText', desc='$rawDesc', id='$viewId'"
                    adBounds.set(bounds)
                    return true
                }

                // ViewId
                if (viewId.contains("sponsored") || viewId.contains("ad_action_button") || viewId.contains("action_button_sponsored") || viewId.contains("reel_ad")) {
                    sponsoredFound = true
                    sponsoredKeyword = "viewId: $viewId"
                    adNodeSummary = "id='$viewId', text='$rawText'"
                    adBounds.set(bounds)
                    return true
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    val found = search(child, depth + 1)
                    if (found) return true
                }
            }
            return false
        }

        search(root, 0)
        return AdDetectionResult(sponsoredFound, sponsoredKeyword, adNodeSummary, adBounds)
    }

    private fun isInstagramReelActive(root: AccessibilityNodeInfo): Boolean {
        var isReelsTabSelected = false
        var isDedicatedClipsViewer = false
        var isHomeFeedVisible = false

        fun search(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 25) return

            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""

            // 1. Detect if Home feed is active (either tab selected, or Home action bar / stories present)
            if ((viewId.contains("feed_tab") || desc.equals("Home", ignoreCase = true) || desc.equals("Feed", ignoreCase = true)) && node.isSelected) {
                isHomeFeedVisible = true
            }
            if (viewId.contains("action_bar_large_title") || viewId.contains("action_bar_inbox_button") || viewId.contains("stories_tray")) {
                isHomeFeedVisible = true
            }

            // 2. Detect if user is on the dedicated Reels tab
            if (viewId.contains("clips_tab") && (node.isSelected || (desc.equals("Reels", ignoreCase = true) && node.isSelected))) {
                isReelsTabSelected = true
                return
            }

            // 3. Dedicated fullscreen standalone Reels viewer
            if (viewId.contains("clips_viewer_view_pager") || viewId.contains("clips_viewer_container")) {
                isDedicatedClipsViewer = true
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    search(child, depth + 1)
                    if (isReelsTabSelected) return
                }
            }
        }

        search(root, 0)

        // If user is anywhere on the Home timeline/feed, NEVER treat as Reel!
        if (isHomeFeedVisible) return false

        return isReelsTabSelected || isDedicatedClipsViewer
    }

    // ==========================================
    // ▶️ YOUTUBE SHORTS DETECTION
    // ==========================================
    private fun isYouTubeShortsActive(root: AccessibilityNodeInfo): Boolean {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        val screenWidth = displayMetrics.widthPixels

        var hasReelProgressBar = false
        var isShortsTabSelected = false
        var isFullscreenShortsPlayer = false

        fun search(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 30) return

            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val text = node.text?.toString()?.trim() ?: ""

            // 1. YouTube Shorts dedicated progress bar (ONLY present in active Shorts viewer!)
            if (viewId.contains("reel_progress_bar")) {
                hasReelProgressBar = true
                return
            }

            // 2. YouTube bottom navigation "Shorts" tab is actively SELECTED
            val isShortsName = desc.equals("Shorts", ignoreCase = true) ||
                    desc.startsWith("Shorts, selected", ignoreCase = true) ||
                    text.equals("Shorts", ignoreCase = true)

            if (isShortsName && node.isSelected) {
                isShortsTabSelected = true
                return
            }

            // 3. Dedicated Fullscreen Shorts player container (taking up full screen)
            // (EXCLUDE home feed shelves like reel_recycler, shorts_shelf, shorts_container)
            val isCarousel = viewId.contains("reel_recycler") || viewId.contains("shorts_shelf") ||
                    viewId.contains("shelf") || viewId.contains("horizontal_list")
            if (!isCarousel && (viewId.contains("shorts_player") || viewId.contains("reel_player_page_view"))) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.height() >= (screenHeight * 0.70) && bounds.width() >= (screenWidth * 0.70)) {
                    isFullscreenShortsPlayer = true
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    search(child, depth + 1)
                    if (hasReelProgressBar || isShortsTabSelected) return
                }
            }
        }

        search(root, 0)
        return hasReelProgressBar || isShortsTabSelected || isFullscreenShortsPlayer
    }

    // ==========================================
    // 👻 SNAPCHAT SPOTLIGHT DETECTION
    // ==========================================
    private fun isSnapchatSpotlightActive(root: AccessibilityNodeInfo): Boolean {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels

        var isSpotlightTabSelected = false
        var isFullscreenSpotlight = false

        fun search(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 20) return

            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.trim() ?: ""
            val text = node.text?.toString()?.trim() ?: ""

            // Bottom bar Spotlight tab selected
            if ((desc.equals("Spotlight", ignoreCase = true) || text.equals("Spotlight", ignoreCase = true)) && node.isSelected) {
                isSpotlightTabSelected = true
                return
            }

            // Fullscreen spotlight container
            if (viewId.contains("spotlight") && (viewId.contains("container") || viewId.contains("player") || viewId.contains("fragment"))) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.height() >= (screenHeight * 0.75)) {
                    isFullscreenSpotlight = true
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    search(child, depth + 1)
                    if (isSpotlightTabSelected) return
                }
            }
        }

        search(root, 0)
        return isSpotlightTabSelected || isFullscreenSpotlight
    }

    // ==========================================
    // 📘 FACEBOOK REELS DETECTION
    // ==========================================
    private fun isFacebookReelsActive(root: AccessibilityNodeInfo): Boolean {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels

        var isReelsActive = false

        fun search(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 20) return

            val viewId = node.viewIdResourceName?.lowercase() ?: ""

            // Only full-screen viewer, NOT the fb_shorts tray on newsfeed
            if (viewId.contains("reels_viewer") || viewId.contains("reel_fullscreen")) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.height() >= (screenHeight * 0.75)) {
                    isReelsActive = true
                    return
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    search(child, depth + 1)
                    if (isReelsActive) return
                }
            }
        }

        search(root, 0)
        return isReelsActive
    }

    // ==========================================
    // 🎵 TIKTOK DETECTION
    // ==========================================
    private fun isTikTokActive(root: AccessibilityNodeInfo): Boolean {
        // Any main video feed in TikTok is short-form vertical video
        return root.packageName?.toString()?.contains("musically") == true ||
                root.packageName?.toString()?.contains("trill") == true
    }

    // ==========================================
    // 🤖 REDDIT & 𝕏 (TWITTER) DETECTION
    // ==========================================
    private fun isRedditShortsActive(root: AccessibilityNodeInfo): Boolean {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        var isShort = false
        fun search(node: AccessibilityNodeInfo?, depth: Int): Boolean {
            if (node == null || depth > 15) return false
            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            if (viewId.contains("immersive_player") || viewId.contains("fullscreen_video_fragment")) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.height() >= (screenHeight * 0.75)) {
                    isShort = true
                    return true
                }
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    if (search(child, depth + 1)) return true
                }
            }
            return false
        }
        search(root, 0)
        return isShort
    }

    private fun isXShortsActive(root: AccessibilityNodeInfo): Boolean {
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        var isShort = false
        fun search(node: AccessibilityNodeInfo?, depth: Int): Boolean {
            if (node == null || depth > 15) return false
            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            if (viewId.contains("immersive_video") || viewId.contains("full_screen_video")) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.height() >= (screenHeight * 0.75)) {
                    isShort = true
                    return true
                }
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    if (search(child, depth + 1)) return true
                }
            }
            return false
        }
        search(root, 0)
        return isShort
    }

    // ==========================================
    // ⚡ GESTURE DISPATCH
    // ==========================================
    private fun performSwipeUp() {
        val displayMetrics = resources.displayMetrics
        val width = displayMetrics.widthPixels.toFloat()
        val height = displayMetrics.heightPixels.toFloat()

        val startX = width * 0.5f
        val startY = height * 0.68f
        val endX = width * 0.5f
        val endY = height * 0.18f

        val swipePath = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }

        val stroke = GestureDescription.StrokeDescription(swipePath, 0L, 190L)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                val newCount = Prefs.incrementSkipCount(this@AdSkipService)
                Log.d(TAG, "Swipe gesture completed. Count: $newCount")
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.w(TAG, "Swipe gesture cancelled")
            }
        }, null)
    }

    fun dumpCurrentHierarchy(): String {
        val root = rootInActiveWindow ?: findApplicationRoot() ?: return "root node is null. Is a supported app currently open?"
        val sb = StringBuilder()
        sb.append("=== ACTIVE UI DUMP ===\n")
        sb.append("Package: ").append(root.packageName).append("\n\n")

        fun dumpNode(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || depth > 25) return
            val indent = "  ".repeat(depth)
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            val text = node.text?.toString() ?: ""
            val desc = node.contentDescription?.toString() ?: ""
            val viewId = node.viewIdResourceName ?: ""
            val className = node.className?.toString()?.substringAfterLast(".") ?: ""

            sb.append(indent).append("[$className] ").append("bounds=$bounds ")
            if (viewId.isNotEmpty()) sb.append("id='$viewId' ")
            if (text.isNotEmpty()) sb.append("text='$text' ")
            if (desc.isNotEmpty()) sb.append("desc='$desc' ")
            sb.append("\n")

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) dumpNode(child, depth + 1)
            }
        }
        dumpNode(root, 0)
        return sb.toString()
    }
}
