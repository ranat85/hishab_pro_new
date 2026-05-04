import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;

/// Firebase service class for Firestore, Auth, and Storage operations
class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final gsign.GoogleSignIn _googleSignIn = gsign.GoogleSignIn();

  // ============ Authentication Methods ============

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  /// Sign in with email and password
  static Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Email Sign-In Error: $e');
      return null;
    }
  }

  /// Create user with email and password
  static Future<UserCredential?> createUserWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Email Sign-Up Error: $e');
      return null;
    }
  }

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('Sign Out Error: $e');
    }
  }

  // ============ Firestore Methods ============

  /// Get reference to user collection
  static CollectionReference get usersCollection {
    return _firestore.collection('users');
  }

  /// Get reference to user's accounts subcollection
  static CollectionReference getUserAccountsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('accounts');
  }

  /// Get reference to user's transactions subcollection
  static CollectionReference getUserTransactionsCollection(
    String userId,
    String accountId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(accountId)
        .collection('transactions');
  }

  /// Save account to Firestore
  static Future<void> saveAccount(
    String userId,
    String accountId,
    Map<String, dynamic> accountData,
  ) async {
    try {
      await getUserAccountsCollection(
        userId,
      ).doc(accountId).set(accountData, SetOptions(merge: true));
    } catch (e) {
      print('Save Account Error: $e');
    }
  }

  /// Get all accounts for user
  static Future<List<Map<String, dynamic>>> getAccounts(String userId) async {
    try {
      final snapshot = await getUserAccountsCollection(userId).get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get Accounts Error: $e');
      return [];
    }
  }

  /// Delete account from Firestore
  static Future<void> deleteAccount(String userId, String accountId) async {
    try {
      // Delete all transactions in the account first
      final txSnapshot = await getUserTransactionsCollection(
        userId,
        accountId,
      ).get();
      for (var doc in txSnapshot.docs) {
        await doc.reference.delete();
      }
      // Then delete the account
      await getUserAccountsCollection(userId).doc(accountId).delete();
    } catch (e) {
      print('Delete Account Error: $e');
    }
  }

  /// Save transaction to Firestore
  static Future<void> saveTransaction(
    String userId,
    String accountId,
    String txId,
    Map<String, dynamic> txData,
  ) async {
    try {
      await getUserTransactionsCollection(
        userId,
        accountId,
      ).doc(txId).set(txData, SetOptions(merge: true));
    } catch (e) {
      print('Save Transaction Error: $e');
    }
  }

  /// Get all transactions for an account
  static Future<List<Map<String, dynamic>>> getTransactions(
    String userId,
    String accountId,
  ) async {
    try {
      final snapshot = await getUserTransactionsCollection(
        userId,
        accountId,
      ).orderBy('date', descending: true).get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get Transactions Error: $e');
      return [];
    }
  }

  /// Delete transaction from Firestore
  static Future<void> deleteTransaction(
    String userId,
    String accountId,
    String txId,
  ) async {
    try {
      await getUserTransactionsCollection(userId, accountId).doc(txId).delete();
    } catch (e) {
      print('Delete Transaction Error: $e');
    }
  }

  // ============ Storage Methods ============

  /// Upload file to Firebase Storage (for backups)
  static Future<String?> uploadBackup(
    String userId,
    String fileName,
    List<int> fileBytes,
  ) async {
    try {
      final ref = _storage.ref().child('backups').child(userId).child(fileName);
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Upload Backup Error: $e');
      return null;
    }
  }

  /// Download backup file from Firebase Storage
  static Future<List<int>?> downloadBackup(
    String userId,
    String fileName,
  ) async {
    try {
      final ref = _storage.ref().child('backups').child(userId).child(fileName);
      final data = await ref.getData();
      return data;
    } catch (e) {
      print('Download Backup Error: $e');
      return null;
    }
  }

  /// List all backups for user
  static Future<List<String>> listBackups(String userId) async {
    try {
      final result = await _storage
          .ref()
          .child('backups')
          .child(userId)
          .listAll();
      return result.items.map((ref) => ref.name).toList();
    } catch (e) {
      print('List Backups Error: $e');
      return [];
    }
  }

  /// Delete backup file from Firebase Storage
  static Future<void> deleteBackup(String userId, String fileName) async {
    try {
      await _storage
          .ref()
          .child('backups')
          .child(userId)
          .child(fileName)
          .delete();
    } catch (e) {
      print('Delete Backup Error: $e');
    }
  }
}
