import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_files.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_validator.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import 'ledger_view_reset.dart';
import '../../sharing/presentation/sharing_screen.dart';

final backupFilesProvider = Provider<BackupFiles>((ref) => BackupFiles());
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

class BackupViewState {
  const BackupViewState({this.preview, this.message, this.error});
  final ValidatedBackup? preview;
  final String? message;
  final String? error;
}

final backupActionsProvider = NotifierProvider<BackupActions, BackupViewState>(
  BackupActions.new,
);

class BackupActions extends Notifier<BackupViewState> {
  @override
  BackupViewState build() => const BackupViewState();

  Future<void> _run(Future<void> Function() action) async {
    if (ref.read(ledgerTransferBusyProvider)) return;
    ref.read(ledgerTransferBusyProvider.notifier).set(true);
    state = BackupViewState(preview: state.preview);
    try {
      await action();
    } catch (error) {
      if (ref.mounted) {
        state = BackupViewState(
          preview: state.preview,
          error: ledgerErrorMessage(error),
        );
      }
    } finally {
      if (ref.mounted) {
        ref.read(ledgerTransferBusyProvider.notifier).set(false);
      }
    }
  }

  Future<void> chooseBackup() => _run(() async {
    // A failed/new selection must never leave an older file ready to restore.
    state = const BackupViewState();
    final bytes = await ref.read(backupFilesProvider).pick();
    if (!ref.mounted) return;
    if (bytes == null) {
      state = const BackupViewState(message: 'File selection cancelled.');
      return;
    }
    final preview = await BackupValidator.decodeInBackground(bytes);
    if (!ref.mounted) return;
    state = BackupViewState(preview: preview);
  });

  Future<void> save() => _run(() async {
    final bytes = await ref.read(backupServiceProvider).exportBytes();
    if (!ref.mounted) return;
    final saved = await ref.read(backupFilesProvider).save(bytes);
    if (!ref.mounted) return;
    state = BackupViewState(
      preview: state.preview,
      message: saved ? 'Backup saved.' : 'Save cancelled.',
    );
  });

  Future<void> share(Rect origin) => _run(() async {
    final bytes = await ref.read(backupServiceProvider).exportBytes();
    if (!ref.mounted) return;
    final status = await ref.read(backupFilesProvider).share(bytes, origin);
    if (!ref.mounted) return;
    state = BackupViewState(
      preview: state.preview,
      message: switch (status) {
        ShareResultStatus.success =>
          'Backup handed to the selected app. Check its destination to confirm it was saved.',
        ShareResultStatus.dismissed => 'Share dismissed.',
        ShareResultStatus.unavailable =>
          'Share result unavailable. Check the destination before relying on this backup.',
      },
    );
  });

  Future<void> restore({required bool safetyBackup}) => _run(() async {
    final preview = state.preview;
    if (preview == null) {
      throw const LedgerException('Choose and validate a backup first.');
    }
    final files = ref.read(backupFilesProvider);
    await ref.read(sharingServiceProvider).stopHost();
    final outcome = await ref
        .read(backupServiceProvider)
        .restore(
          preview,
          saveSafetyBackup: safetyBackup
              ? (bytes) => files.save(bytes, safety: true)
              : null,
        );
    if (!ref.mounted) return;
    if (outcome == RestoreOutcome.cancelled) {
      state = BackupViewState(
        preview: preview,
        message: 'Safety backup cancelled. Your ledger has not been replaced.',
      );
      return;
    }
    // Recreate navigation and discard forms/search/period selection belonging
    // to the previous ledger. Database streams refresh from committed tables.
    state = const BackupViewState(message: 'Backup restored.');
    resetLedgerViews(ref);
  });
}
