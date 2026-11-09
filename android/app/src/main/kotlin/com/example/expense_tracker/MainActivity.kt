package com.example.expense_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updates by lazy { UpdateInstaller(this) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "expense_tracker/updates")
            .setMethodCallHandler(updates::handle)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expense_tracker/private_storage"
        ).setMethodCallHandler { call, result ->
            if (call.method != "prepareLedgerDirectory") {
                result.notImplemented()
            } else {
                try {
                    // Persistent internal storage excluded from OS backups.
                    val directory = File(noBackupFilesDir, "ledger")
                    check(directory.isDirectory || directory.mkdirs())
                    result.success(directory.absolutePath)
                } catch (error: Exception) {
                    // Do not send filesystem paths or ledger details to logs/UI.
                    result.error("storage_unavailable", "Cannot prepare ledger storage", null)
                }
            }
        }
    }

    override fun onDestroy() {
        updates.close()
        super.onDestroy()
    }
}
