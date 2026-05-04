import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// Migration helper to sync local SQLite data to Firebase Firestore
class FirestoreMigrationHelper {
  /// Migrate all accounts and transactions from local storage to Firestore
  /// Requires user to be authenticated
  static Future<bool> migrateLocalDataToFirestore(
    List<Map<String, dynamic>> accounts,
    Map<String, List<Map<String, dynamic>>> accountTransactions,
  ) async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) {
        print('User not authenticated. Cannot migrate data.');
        return false;
      }

      final userId = user.uid;

      // Save each account and its transactions to Firestore
      for (final account in accounts) {
        final accountId =
            account['id'] ?? 'account_${DateTime.now().millisecondsSinceEpoch}';

        // Save account metadata
        await FirebaseService.saveAccount(userId, accountId, {
          'name': account['name'] ?? '',
          'credit': account['credit'] ?? 0.0,
          'debit': account['debit'] ?? 0.0,
          'balance': account['balance'] ?? 0.0,
          'createdAt': account['createdAt'] ?? DateTime.now().toIso8601String(),
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        // Save transactions for this account
        final txList = accountTransactions[accountId] ?? [];
        for (final tx in txList) {
          final txId =
              tx['id'] ?? 'tx_${DateTime.now().millisecondsSinceEpoch}';
          await FirebaseService.saveTransaction(userId, accountId, txId, {
            'date': tx['date'] ?? '',
            'particular': tx['particular'] ?? '',
            'credit': tx['credit'] ?? 0.0,
            'debit': tx['debit'] ?? 0.0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      print('Migration completed successfully!');
      return true;
    } catch (e) {
      print('Migration error: $e');
      return false;
    }
  }

  /// Check if Firestore data exists for current user
  static Future<bool> firestoreDataExists() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) return false;

      final accounts = await FirebaseService.getAccounts(user.uid);
      return accounts.isNotEmpty;
    } catch (e) {
      print('Error checking Firestore data: $e');
      return false;
    }
  }

  /// Load all accounts from Firestore for current user
  static Future<List<Map<String, dynamic>>> loadAccountsFromFirestore() async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) return [];

      return await FirebaseService.getAccounts(user.uid);
    } catch (e) {
      print('Error loading accounts from Firestore: $e');
      return [];
    }
  }

  /// Load transactions for a specific account from Firestore
  static Future<List<Map<String, dynamic>>> loadTransactionsFromFirestore(
    String accountId,
  ) async {
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) return [];

      return await FirebaseService.getTransactions(user.uid, accountId);
    } catch (e) {
      print('Error loading transactions from Firestore: $e');
      return [];
    }
  }
}
