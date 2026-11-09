package com.example.expense_tracker

import android.content.Intent
import android.content.ClipData
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.zip.ZipFile

class UpdateInstaller(private val activity: MainActivity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val directory get() = File(activity.cacheDir, "updates")

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val certificates = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return certificates?.map { hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray())) }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private val signingFlags get() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun installed() = activity.packageManager.getPackageInfo(activity.packageName, signingFlags)

    @Suppress("DEPRECATION")
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }

    private fun verify(call: MethodCall): File {
        val expectedVersion = call.argument<Number>("versionCode")?.toLong() ?: error("Missing version")
        val size = call.argument<Number>("size")?.toLong() ?: error("Missing size")
        val hash = call.argument<String>("sha256") ?: error("Missing checksum")
        val file = File(call.argument<String>("path") ?: "").canonicalFile
        check(file == File(directory, "update.apk").canonicalFile && file.isFile)
        check(size in 1L..268435456L && file.length() == size && hash.matches(Regex("[a-f0-9]{64}")))
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        check(hex(digest.digest()) == hash)
        val archive = activity.packageManager.getPackageArchiveInfo(file.path, signingFlags) ?: error("Invalid APK")
        val current = installed()
        check(archive.packageName == activity.packageName)
        check(version(archive) == expectedVersion && expectedVersion > version(current))
        val trusted = signatures(current)
        check(trusted.isNotEmpty() && signatures(archive) == trusted)
        ZipFile(file).use { zip ->
            val libraries = zip.entries().asSequence().filter { it.name.startsWith("lib/") && it.name.endsWith(".so") }.toList()
            check(libraries.isNotEmpty() && libraries.all { it.name.startsWith("lib/arm64-v8a/") })
        }
        return file
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "installedInfo" -> {
                    val info = installed()
                    result.success(mapOf("version" to info.versionName, "versionCode" to version(info), "arm64" to Build.SUPPORTED_ABIS.contains("arm64-v8a")))
                }
                "prepareUpdateDirectory" -> {
                    check(directory.isDirectory || directory.mkdirs())
                    File(directory, "update.apk").delete()
                    result.success(directory.absolutePath)
                }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
                "requestInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                    }
                    result.success(null)
                }
                "verifyApk", "installApk" -> executor.execute {
                    try {
                        val file = verify(call)
                        activity.runOnUiThread {
                            try {
                                if (call.method == "installApk") {
                                    check(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
                                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                                    val intent = Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, "application/vnd.android.package-archive")
                                        clipData = ClipData.newRawUri("App update", uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    activity.startActivity(intent)
                                }
                                result.success(null)
                            } catch (_: Exception) {
                                result.error("update_install_failed", "Cannot open Android's update installer. Try again.", null)
                            }
                        }
                    } catch (_: Exception) {
                        fileCleanup()
                        activity.runOnUiThread { result.error("update_verification_failed", "The downloaded APK failed verification. Download it again.", null) }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("update_unavailable", "Cannot prepare app updates on this device.", null)
        }
    }

    private fun fileCleanup() { File(directory, "update.apk").delete() }
    fun close() { executor.shutdown() }
}
