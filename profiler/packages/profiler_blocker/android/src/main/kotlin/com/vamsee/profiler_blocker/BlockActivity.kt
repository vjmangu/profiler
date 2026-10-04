package com.vamsee.profiler_blocker

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Full-screen "This app is blocked" notice. Built in code: no layout XML. */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = intent.getStringExtra(EXTRA_APP) ?: "This app"
        val profile = intent.getStringExtra(EXTRA_PROFILE) ?: "your profile"

        fun dp(v: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
        ).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            setBackgroundColor(Color.parseColor("#1E1B4B"))
        }
        root.addView(TextView(this).apply {
            text = "🔒" // lock emoji
            textSize = 64f
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = "$app is blocked"
            textSize = 26f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, dp(8))
        })
        root.addView(TextView(this).apply {
            text = "The $profile profile is on. Open Profiler to switch profiles."
            textSize = 16f
            setTextColor(Color.parseColor("#C7D2FE"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(32))
        })
        root.addView(Button(this).apply {
            text = "OK"
            setTextColor(Color.parseColor("#1E1B4B"))
            background = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(Color.WHITE)
            }
            setPadding(dp(48), dp(12), dp(48), dp(12))
            setOnClickListener { goHome() }
        })
        setContentView(root)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }

    companion object {
        const val EXTRA_APP = "app"
        const val EXTRA_PROFILE = "profile"
    }
}
