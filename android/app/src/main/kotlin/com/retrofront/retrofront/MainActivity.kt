package com.retrofront.retrofront

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.hardware.input.InputManager
import android.net.Uri
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
                    val args = call.arguments as? Map<*, *>
                    val rom = args?.get("rom") as? String ?: ""
                    val core = args?.get("core") as? String
                    result.success(launchRetroArch(rom, core))
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrofront/update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.arguments as? String ?: ""
                    result.success(installApk(path))
                }
                "openUrl" -> {
                    val url = call.arguments as? String ?: ""
                    result.success(openUrl(url))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "retrofront/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAllFilesAccess" -> {
                    result.success(isManageExternalStorageGranted())
                }
                "openAllFilesAccess" -> {
                    result.success(openManageExternalStorage())
                }
                "openAppSettings" -> {
                    result.success(openAppSettings())
                }
                "getSdkInt" -> {
                    result.success(android.os.Build.VERSION.SDK_INT)
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

    private val retroarchPackages = listOf(
        "com.retroarch",
        "com.retroarch.bq.plus",
        "com.retroarch.aarch64"
    )

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

    /** Lanca o jogo no RetroArch. Retorna null em caso de sucesso, ou uma
     *  mensagem de erro para o usuario (null nunca e lido como sucesso). */
    private fun launchRetroArch(romPath: String, corePath: String?): String? {
        val pkg = findRetroArchPackage()
        if (pkg == null) {
            return "RetroArch não está instalado. Instale o RetroArch na Play Store " +
                "ou em retroarch.com para jogar."
        }
        if (!File(romPath).exists()) {
            return "O arquivo do jogo não foi encontrado: $romPath"
        }

        // 1) Estilo ES-DE: intent direto forcando o core (RetroActivityFuture),
        // abrindo o jogo ja com o emulador/core certo, sem telas intermediarias.
        if (!corePath.isNullOrEmpty()) {
            val target = resolveCoreTarget(corePath, pkg)
            if (target == null) {
                return "O núcleo (core) deste console não está instalado no RetroArch. " +
                    "Abra o RetroArch, acesse \"Online Updater\" -> \"Core Updater\" e " +
                    "instale o core correspondente, depois tente abrir o jogo novamente."
            }
            if (launchWithCore(target.first, romPath, target.second)) return null
            return "Não foi possível abrir o jogo no RetroArch."
        }

        // 2) Fallback: FileProvider + ACTION_VIEW (RetroArch escolhe o core).
        return if (launchByView(romPath)) null
        else "Não foi possível abrir o jogo. O formato pode não ser suportado pelo RetroArch."
    }

    /** Encontra o arquivo do core realmente instalado: o core pode não existir
     *  no pacote detectado primeiro, mas sim em outro RetroArch instalado
     *  (ex.: cores do com.retroarch.aarch64 com o com.retroarch detectado). */
    private fun resolveCoreTarget(corePath: String, detectedPkg: String): Pair<String, String>? {
        val coreFile = corePath.substringAfterLast('/')
        val candidates = mutableListOf<String>()
        if (detectedPkg.isNotEmpty()) candidates.add(detectedPkg)
        for (pkg in retroarchPackages) if (pkg !in candidates) candidates.add(pkg)
        for (pkg in candidates) {
            if (!isPackageInstalled(pkg)) continue
            val file = File("/data/data/$pkg/cores/$coreFile")
            if (file.exists()) return pkg to file.absolutePath
        }
        return null
    }

    private fun isPackageInstalled(pkg: String): Boolean = try {
        applicationContext.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: Exception) {
        false
    }

    /** Abre a ROM no RetroArch ja com o core definido, estilo ES-DE. */
    private fun launchWithCore(pkg: String, romPath: String, corePath: String): Boolean {
        val activity = "$pkg.browser.retroactivity.RetroActivityFuture"
        val intent = Intent().apply {
            setClassName(pkg, activity)
            action = Intent.ACTION_VIEW
            putExtra("ROM", romPath)
            putExtra("LIBRETRO", corePath)
            retroarchConfig(pkg)?.let { putExtra("CONFIGFILE", it) }
        }
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Caminho do retroarch.cfg do RetroArch, se ja existir (null = usa o padrao). */
    private fun retroarchConfig(pkg: String): String? {
        val candidates = listOf(
            "/storage/emulated/0/Android/data/$pkg/files/retroarch.cfg",
            "/data/data/$pkg/retroarch.cfg"
        )
        return candidates.firstOrNull { File(it).exists() }
    }

    private fun launchByView(romPath: String): Boolean {
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

    /** Baixa o APK via FileProvider e abre o instalador do Android. */
    private fun installApk(apkPath: String): Boolean {
        val context = applicationContext
        val file = File(apkPath)
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
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Abre uma URL no navegador do sistema (ex.: pagina de releases do GitHub). */
    private fun openUrl(url: String): Boolean {
        if (url.isEmpty()) return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Android 11+ (API 30+): MANAGE_EXTERNAL_STORAGE ("All files access").
     *  Retorna null em versoes antigas para o Dart cair no fluxo de storage. */
    private fun isManageExternalStorageGranted(): Boolean? {
        if (android.os.Build.VERSION.SDK_INT < 30) return null
        return android.os.Environment.isExternalStorageManager()
    }

    /** Abre a tela de "All files access" do sistema (Android 11+). */
    private fun openManageExternalStorage(): Boolean {
        if (android.os.Build.VERSION.SDK_INT < 30) return false
        val intent = Intent(
            android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName")
        )
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            // Fallback para alguns OEMs: tela global (sem filtrar pelo app).
            try {
                startActivity(
                    Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                )
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    /** Abre as configuracoes do app (onde fica o toggle de permissao). */
    private fun openAppSettings(): Boolean {
        val context = applicationContext
        val intent = Intent(
            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName")
        )
        return try {
            startActivity(intent)
            true
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
