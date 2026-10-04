package com.vamsee.profiler_blocker

import android.content.Context
import org.json.JSONObject
import java.util.Calendar

/** Weekly window. Days: 1 = Monday … 7 = Sunday. Minutes after midnight. */
data class ScheduleCfg(val days: Set<Int>, val start: Int, val end: Int) {
    fun isActive(cal: Calendar): Boolean {
        if (days.isEmpty()) return false
        // Calendar: SUNDAY=1 … SATURDAY=7  ->  ISO: MONDAY=1 … SUNDAY=7
        val dow = ((cal.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
        val m = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        if (end > start) return dow in days && m >= start && m < end
        val prev = if (dow == 1) 7 else dow - 1
        return (dow in days && m >= start) || (prev in days && m < end)
    }
}

data class ProfileCfg(
    val id: String,
    val name: String,
    val blocked: Set<String>,
    val tamperProtection: Boolean,
    val schedule: ScheduleCfg?,
)

/**
 * Mirror of the Dart-side rules so blocking keeps working while the Flutter
 * UI is closed: a manually started profile wins, otherwise the first profile
 * whose schedule covers "now" (unless it was paused until its window ends).
 */
class BlockerConfig(
    val manualActiveId: String?,
    val snoozedId: String?,
    val snoozeUntil: Long,
    val profiles: List<ProfileCfg>,
) {
    fun effective(nowMs: Long = System.currentTimeMillis()): ProfileCfg? {
        manualActiveId?.let { id -> profiles.firstOrNull { it.id == id }?.let { return it } }
        val cal = Calendar.getInstance().apply { timeInMillis = nowMs }
        return profiles.firstOrNull { p ->
            val s = p.schedule ?: return@firstOrNull false
            val snoozed = p.id == snoozedId && nowMs < snoozeUntil
            !snoozed && s.isActive(cal)
        }
    }

    /** Packages blocked right now, plus whether tamper protection is on. */
    fun blockedNow(): Pair<ProfileCfg, Set<String>>? {
        val p = effective() ?: return null
        val set = if (p.tamperProtection) p.blocked + TAMPER_PACKAGES else p.blocked
        return p to set
    }

    companion object {
        private const val PREFS = "profiler_blocker"
        private const val KEY = "config"

        /** Ways to switch the blocker off from outside the app. */
        val TAMPER_PACKAGES = setOf(
            "com.android.settings",
            "com.google.android.settings.intelligence",
            "com.android.vending",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.samsung.android.app.galaxyfinder",
            "com.sec.android.app.samsungapps",
        )

        private val EMPTY = BlockerConfig(null, null, 0L, emptyList())

        @Volatile
        private var cached: BlockerConfig? = null

        fun get(context: Context): BlockerConfig {
            cached?.let { return it }
            val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null)
            val cfg = json?.let { runCatching { parse(it) }.getOrNull() } ?: EMPTY
            cached = cfg
            return cfg
        }

        fun save(context: Context, json: String) {
            val cfg = parse(json) // throws on bad input before we persist it
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, json).apply()
            cached = cfg
        }

        private fun JSONObject.optStringOrNull(key: String): String? =
            if (isNull(key)) null else optString(key)

        fun parse(json: String): BlockerConfig {
            val o = JSONObject(json)
            val arr = o.optJSONArray("profiles")
            val profiles = mutableListOf<ProfileCfg>()
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    val p = arr.getJSONObject(i)
                    val blockedArr = p.optJSONArray("blocked")
                    val blocked = mutableSetOf<String>()
                    if (blockedArr != null) {
                        for (j in 0 until blockedArr.length()) blocked += blockedArr.getString(j)
                    }
                    val schedule = if (p.isNull("schedule")) null else {
                        val s = p.getJSONObject("schedule")
                        val daysArr = s.getJSONArray("days")
                        val days = (0 until daysArr.length()).map { daysArr.getInt(it) }.toSet()
                        ScheduleCfg(days, s.getInt("start"), s.getInt("end"))
                    }
                    profiles += ProfileCfg(
                        id = p.getString("id"),
                        name = p.optString("name", "Profile"),
                        blocked = blocked,
                        tamperProtection = p.optBoolean("tamperProtection", false),
                        schedule = schedule,
                    )
                }
            }
            return BlockerConfig(
                manualActiveId = o.optStringOrNull("manualActiveId"),
                snoozedId = o.optStringOrNull("snoozedId"),
                snoozeUntil = if (o.isNull("snoozeUntil")) 0L else o.optLong("snoozeUntil", 0L),
                profiles = profiles,
            )
        }
    }
}
