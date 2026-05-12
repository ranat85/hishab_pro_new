import 'dart:typed_data';
import 'dart:developer' as developer;
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
      final gsign.GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn();
      if (googleUser == null) return null;

      final gsign.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      developer.log('Google Sign-In Error: $e', name: 'FirebaseService');
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
      developer.log('Email Sign-In Error: $e', name: 'FirebaseService');
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
      developer.log('Email Sign-Up Error: $e', name: 'FirebaseService');
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
      developer.log('Sign Out Error: $e', name: 'FirebaseService');
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
      developer.log('Save Account Error: $e', name: 'FirebaseService');
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
      developer.log('Get Accounts Error: $e', name: 'FirebaseService');
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
      developer.log('Delete Account Error: $e', name: 'FirebaseService');
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
      developer.log('Save Transaction Error: $e', name: 'FirebaseService');
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
      developer.log('Get Transactions Error: $e', name: 'FirebaseService');
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
      developer.log('Delete Transaction Error: $e', name: 'FirebaseService');
    }
  }

  // ============ Storage Methods ============

  /// Upload file to Firebase Storage (for backups)
  static Future<String?> uploadBackup(
    String userId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    try {
      final ref = _storage.ref().child('backups').child(userId).child(fileName);
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      developer.log('Upload Backup Error: $e', name: 'FirebaseService');
      return null;
    }
  }

  /// Download backup file from Firebase Storage
  static Future<Uint8List?> downloadBackup(
    String userId,
    String fileName,
  ) async {
    try {
      final ref = _storage.ref().child('backups').child(userId).child(fileName);
      final Uint8List? data = await ref.getData();
      return data;
    } catch (e) {
      developer.log('Download Backup Error: $e', name: 'FirebaseService');
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
