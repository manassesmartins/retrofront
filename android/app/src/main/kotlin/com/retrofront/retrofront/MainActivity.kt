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
                "detectRetroArch" -> {
                    result.success(findRetroArchPackage())
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrofront/system"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorage" -> {
                    result.success(storageInfo())
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Espaço livre/total do armazenamento (bytes), usado nas Configurações. */
    private fun storageInfo(): Map<String, Long> {
        return try {
            val stat = android.os.StatFs(
                android.os.Environment.getExternalStorageDirectory()?.path
                    ?: android.os.Environment.getDataDirectory().path
            )
            mapOf(
                "free" to stat.availableBytes,
                "total" to stat.totalBytes
            )
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private val retroarchPackages = listOf("com.retroarch", "com.retroarch.bq.plus")

    /** Encontra o pacote do RetroArch instalado (qualquer versao do Android). */
    private fun findRetroArchPackage(): String? {
        val pm = applicationContext.packageManager
        // 1) Pacotes conhecidos (visiveis em Android 11+ via <queries>).
        for (pkg in retroarchPackages) {
            try {
                pm.getPackageInfo(pkg, 0)
                return pkg
            } catch (e: Exception) {
                // nao instalado
            }
        }
        // 2) Fallback: atividades que abrem arquivos cujo pacote tem "retroarch".
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply { type = "*/*" }
            pm.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .firstOrNull { it.contains("retroarch", ignoreCase = true) }
        } catch (e: Exception) {
            null
        }
    }

    private fun launchRetroArch(romPath: String): Boolean {
        val context = applicationContext
        val pkg = findRetroArchPackage() ?: return false

        val file = File(romPath)
        if (!file.exists()) return false

        val uri = try {
            FileProvider.getUriForFile(
                context,
                "$packageName.fileprovider",
                file
            )
        } catch (e: Exception) {
            return false
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            data = uri
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // 1) Abre no RetroArch detectado.
        return try {
            intent.setPackage(pkg)
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            // 2) Fallback: deixa o sistema resolver (seletor de apps).
            try {
                intent.setPackage(null)
                startActivity(intent)
                true
            } catch (e2: Exception) {
                false
            }
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
