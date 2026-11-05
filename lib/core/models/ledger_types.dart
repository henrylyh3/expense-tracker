enum TransactionType { income, expense }

enum RemovalOutcome { deleted, archived }

/// Only these deliberately written messages may be shown directly to a user.
class LedgerException implements Exception {
  const LedgerException(this.message);
  final String message;

  @override
  String toString() => message;
}

String ledgerErrorMessage(Object? error) => error is LedgerException
    ? error.message
    : 'Could not complete the change. Please try again.';
