package com.vamsee.profiler_blocker

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class ProfilerBlockerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "profiler_blocker")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> io.execute {
                val apps = runCatching { installedApps() }
                main.post {
                    apps.fold(
                        { result.success(it) },
                        { result.error("APPS_FAILED", it.message, null) },
                    )
                }
            }

            "isServiceEnabled" -> result.success(isServiceEnabled())

            "requestPermission" -> {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                val a = activity
                if (a != null) a.startActivity(intent)
                else context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            }

            "syncConfig" -> {
                val json = call.argument<String>("json")
                if (json == null) {
                    result.error("BAD_ARGS", "json missing", null)
                    return
                }
                try {
                    BlockerConfig.save(context, json)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("BAD_CONFIG", e.message, null)
                }
            }

            // iOS-only calls: harmless no-ops here.
            "pickApps" -> result.success(null)
            "selectionCount" -> result.success(0)
            "clearProfile" -> result.success(null)

            else -> result.notImplemented()
        }
    }

    private fun isServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val me = ComponentName(context, BlockerAccessibilityService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    private fun installedApps(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any?>>()
        for (ri in pm.queryIntentActivities(launcher, 0)) {
            val ai = ri.activityInfo.applicationInfo
            val pkg = ai.packageName
            if (pkg == context.packageName || !seen.add(pkg)) continue
            val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ai.category else -1
            out += mapOf(
                "package" to pkg,
                "label" to ri.loadLabel(pm).toString(),
                "category" to category,
                "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "icon" to runCatching { iconBytes(ri.loadIcon(pm)) }.getOrNull(),
            )
        }
        return out
    }

    private fun iconBytes(d: Drawable, size: Int = 96): ByteArray {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(canvas)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }
}
