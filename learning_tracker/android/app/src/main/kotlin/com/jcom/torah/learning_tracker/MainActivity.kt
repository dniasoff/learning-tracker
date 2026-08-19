package com.jcom.torah.learning_tracker

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Restore normal window fitting before Flutter draws its first frame.
        // Android 9 can retain the launch window's edge-to-edge layout flags after
        // Flutter switches to NormalTheme, which leaves the bottom inset at zero.
        restoreSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Flutter applies its platform system-UI configuration after onCreate.
            // Re-apply the fitting policy once the Flutter view owns focus.
            restoreSystemBars()
        }
    }

    @Suppress("DEPRECATION")
    private fun restoreSystemBars() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)

        val legacyHiddenFlags =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        val legacyLayoutFlags =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        window.decorView.systemUiVisibility =
            window.decorView.systemUiVisibility and
                (legacyHiddenFlags or legacyLayoutFlags).inv()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(true)
            window.insetsController?.show(
                WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
            )
        }
    }
}
