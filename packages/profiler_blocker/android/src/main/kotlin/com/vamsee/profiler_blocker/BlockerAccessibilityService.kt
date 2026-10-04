package com.vamsee.profiler_blocker

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent

/**
 * Watches which app comes to the foreground and bounces blocked ones to the
 * home screen with a "blocked" notice. Reads only the package name.
 */
class BlockerAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastPackage: String? = null
    private var lastBlockedPkg: String? = null
    private var lastBlockedAt = 0L
    private val alwaysAllowed = mutableSetOf<String>()

    /** Re-check periodically so a schedule that starts while a blocked app
     *  is already open still takes effect. */
    private val recheck = object : Runnable {
        override fun run() {
            lastPackage?.let { evaluate(it) }
            handler.postDelayed(this, RECHECK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        alwaysAllowed += packageName
        alwaysAllowed += "com.android.systemui"
        alwaysAllowed += "android"
        // Never block the launcher, or there'd be nowhere to go.
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        packageManager.queryIntentActivities(home, 0)
            .forEach { alwaysAllowed += it.activityInfo.packageName }
        handler.postDelayed(recheck, RECHECK_MS)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        // Keyboards & overlays fire events too; only track real app windows.
        if (event.className?.toString()?.contains("InputMethod") == true) return
        lastPackage = pkg
        evaluate(pkg)
    }

    private fun evaluate(pkg: String) {
        if (pkg in alwaysAllowed) return
        val (profile, blocked) = BlockerConfig.get(this).blockedNow() ?: return
        if (pkg !in blocked) return

        // Debounce: one app can fire several window events in a burst.
        val now = SystemClock.elapsedRealtime()
        if (pkg == lastBlockedPkg && now - lastBlockedAt < 800) return
        lastBlockedPkg = pkg
        lastBlockedAt = now

        performGlobalAction(GLOBAL_ACTION_HOME)
        val label = runCatching {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0)
            ).toString()
        }.getOrDefault(pkg)

        startActivity(
            Intent(this, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(BlockActivity.EXTRA_APP, label)
                .putExtra(BlockActivity.EXTRA_PROFILE, profile.name)
        )
        lastPackage = packageName
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        handler.removeCallbacks(recheck)
        super.onDestroy()
    }

    companion object {
        private const val RECHECK_MS = 15_000L
    }
}
