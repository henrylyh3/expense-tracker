import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import 'startup_recovery_screen.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(databaseReadyProvider)
      .when(
        skipLoadingOnRefresh: false,
        data: (_) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        loading: () => const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Opening your ledger…'),
              ],
            ),
          ),
        ),
        error: (error, stack) => const _StartupFailure(),
      );
}

class _StartupFailure extends ConsumerStatefulWidget {
  const _StartupFailure();
  @override
  ConsumerState<_StartupFailure> createState() => _StartupFailureState();
}

class _StartupFailureState extends ConsumerState<_StartupFailure> {
  bool _recovering = false;
  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    if (_recovering) {
      return StartupRecoveryScreen(
        onCancel: () => setState(() => _recovering = false),
      );
    }
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 48),
                    const SizedBox(height: 24),
                    Text(
                      'Unable to open your ledger',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your ledger has not been reset or repaired. Check available storage and try again. '
                      'You can also recover from a validated JSON backup while retaining the original files.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              ref.invalidate(databaseProvider);
                              ref.invalidate(databaseReadyProvider);
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => setState(() => _recovering = true),
                      icon: const Icon(Icons.restore),
                      label: const Text('Recover from backup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
