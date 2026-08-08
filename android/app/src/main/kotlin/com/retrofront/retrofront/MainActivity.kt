package com.retrofront.retrofront

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.hardware.input.InputManager
import android.os.Handler
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity
import java.io.File

class MainActivity : FlutterActivity(), GamepadsCompatibleActivity {

    private var inputDeviceListener: InputManager.InputDeviceListener? = null
    private var keyHandler: ((KeyEvent) -> Boolean)? = null
    private var motionHandler: ((MotionEvent) -> Boolean)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrofront/launcher"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchRetroArch" -> {
                    val path = call.arguments as? String ?: ""
                    result.success(launchRetroArch(path))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchRetroArch(romPath: String): Boolean {
        val context = applicationContext
        val retroArchInstalled = try {
            context.packageManager.getPackageInfo("com.retroarch", 0)
            true
        } catch (e: Exception) {
            false
        }
        if (!retroArchInstalled) return false

        val file = File(romPath)
        if (!file.exists()) return false

        return try {
            val uri = FileProvider.getUriForFile(
                context,
                "$packageName.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = uri
                type = "*/*"
                setPackage("com.retroarch")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    // ---- Gamepads plugin: encaminha eventos de controles (USB/Bluetooth) ----

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        val handled = motionHandler?.invoke(event) ?: false
        return handled || super.dispatchGenericMotionEvent(event)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val handled = keyHandler?.invoke(event) ?: false
        return handled || super.dispatchKeyEvent(event)
    }

    override fun registerInputDeviceListener(
        listener: InputManager.InputDeviceListener,
        handler: Handler?
    ) {
        inputDeviceListener?.let {
            (getSystemService(Context.INPUT_SERVICE) as InputManager)
                .unregisterInputDeviceListener(it)
        }
        inputDeviceListener = listener
        (getSystemService(Context.INPUT_SERVICE) as InputManager)
            .registerInputDeviceListener(listener, handler)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyHandler = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionHandler = handler
    }
}
