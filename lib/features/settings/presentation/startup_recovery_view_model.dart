import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_validator.dart';
import '../../../core/backup/startup_recovery_service.dart';
import '../../../core/database/ledger_storage.dart';
import '../../../core/database/private_storage.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import 'backup_view_model.dart';
import 'ledger_view_reset.dart';

final startupRecoveryServiceProvider = Provider<StartupRecoveryService>(
  (ref) => StartupRecoveryService(
    storage: () async =>
        LedgerStorage(Directory(await prepareLedgerDirectory())),
    closeCurrentDatabase: () => ref.read(databaseProvider).close(),
  ),
);

class StartupRecoveryState {
  const StartupRecoveryState({
    this.preview,
    this.stage,
    this.error,
    this.message,
  });
  final ValidatedBackup? preview;
  final RecoveryStage? stage;
  final String? error;
  final String? message;
}

final startupRecoveryProvider =
    NotifierProvider<StartupRecoveryActions, StartupRecoveryState>(
      StartupRecoveryActions.new,
    );

class StartupRecoveryActions extends Notifier<StartupRecoveryState> {
  @override
  StartupRecoveryState build() => const StartupRecoveryState();

  Future<void> _run(Future<void> Function() action) async {
    if (ref.read(ledgerTransferBusyProvider)) return;
    if (!ref.read(databaseReadyProvider).hasError) {
      state = const StartupRecoveryState(
        error:
            'Startup recovery is only available when the ledger cannot open.',
      );
      return;
    }
    ref.read(ledgerTransferBusyProvider.notifier).set(true);
    state = StartupRecoveryState(preview: state.preview);
    try {
      await action();
    } catch (error) {
      if (ref.mounted) {
        state = StartupRecoveryState(
          preview: state.preview,
          error: error is LedgerException
              ? error.message
              : 'Recovery did not finish. Your previous ledger is retained in place or in private preservation copies. Check storage and try again.',
        );
      }
    } finally {
      if (ref.mounted) ref.read(ledgerTransferBusyProvider.notifier).set(false);
    }
  }

  Future<void> chooseBackup() => _run(() async {
    state = const StartupRecoveryState();
    final bytes = await ref.read(backupFilesProvider).pick();
    if (!ref.mounted) return;
    if (bytes == null) {
      state = const StartupRecoveryState(message: 'File selection cancelled.');
      return;
    }
    final preview = await BackupValidator.decodeInBackground(bytes);
    if (ref.mounted) state = StartupRecoveryState(preview: preview);
  });

  Future<void> recover() => _run(() async {
    final backup = state.preview;
    if (backup == null) {
      throw const LedgerException('Choose and validate a backup first.');
    }
    await ref
        .read(startupRecoveryServiceProvider)
        .recover(
          backup,
          onStage: (stage) {
            if (ref.mounted) {
              state = StartupRecoveryState(preview: backup, stage: stage);
            }
          },
        );
    if (!ref.mounted) return;
    // Activation is committed. Reopen through the selector; any failure keeps
    // the recovered file and original archive available for another attempt.
    state = const StartupRecoveryState();
    ref.invalidate(backupActionsProvider);
    ref.invalidate(databaseProvider);
    ref.invalidate(databaseReadyProvider);
    resetLedgerViews(ref);
  });
}
