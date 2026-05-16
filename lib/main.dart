// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;
import 'package:path_provider/path_provider.dart';
// removed unused dart:typed_data import (foundation provides debug util)
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'firebase_options.dart';
// AdMob removed per user request
import 'firebase_service.dart';

// Simple authenticated HTTP client that injects Google auth headers.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// Full-screen setup screen that forces the user to set password and enable fingerprint
class SetupAuthScreen extends StatefulWidget {
  final LocalAuthentication localAuth;
  const SetupAuthScreen({required this.localAuth, super.key});

  @override
  State<SetupAuthScreen> createState() => _SetupAuthScreenState();
}

class _SetupAuthScreenState extends State<SetupAuthScreen> {
  final TextEditingController _pwdCtrl = TextEditingController();
  bool _pwdSaved = false;
  bool _fingerprintOk = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final ok =
          await widget.localAuth.canCheckBiometrics ||
          await widget.localAuth.isDeviceSupported();
      if (mounted) {
        setState(() => _biometricAvailable = ok);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _biometricAvailable = false);
      }
    }
  }

  Future<void> _savePassword() async {
    final v = _pwdCtrl.text.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_password', v);
    if (mounted) {
      setState(() => _pwdSaved = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password saved')));
    }
  }

  Future<void> _enableFingerprint() async {
    try {
      if (!_biometricAvailable) return;
      final ok = await widget.localAuth.authenticate(
        localizedReason: 'Verify fingerprint to enable biometric login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('unlock_with_fingerprint', true);
        // read back to confirm it was saved
        final confirmed = prefs.getBool('unlock_with_fingerprint') ?? false;
        if (confirmed) {
          if (mounted) {
            setState(() => _fingerprintOk = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fingerprint enabled')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to enable fingerprint')),
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'HISHAB PRO',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Set a password and enable fingerprint to continue',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Set app password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePassword,
                    child: Text(_pwdSaved ? 'Password saved' : 'Save password'),
                  ),
                ),
                const SizedBox(height: 24),

                // Fingerprint area
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fingerprint,
                      size: 64,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _biometricAvailable ? _enableFingerprint : null,
                    child: Text(
                      _fingerprintOk
                          ? 'Fingerprint enabled'
                          : (_biometricAvailable
                                ? 'Enable fingerprint'
                                : 'Fingerprint not available'),
                    ),
                  ),
                ),

                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_pwdSaved && _fingerprintOk)
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: const Text('Finish'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Global cached currency symbol so other screens can access it quickly.
String appCurrencySymbol = '৳';

// Full-screen fingerprint login screen
class FingerprintLoginScreen extends StatefulWidget {
  final LocalAuthentication localAuth;
  const FingerprintLoginScreen({required this.localAuth, super.key});

  @override
  State<FingerprintLoginScreen> createState() => _FingerprintLoginScreenState();
}

class _FingerprintLoginScreenState extends State<FingerprintLoginScreen> {
  @override
  void initState() {
    super.initState();
    _startAuth();
  }

  Future<void> _startAuth() async {
    try {
      final canCheck =
          await widget.localAuth.canCheckBiometrics ||
          await widget.localAuth.isDeviceSupported();
      if (!canCheck) {
        setState(() {});
        return;
      }
      final ok = await widget.localAuth.authenticate(
        localizedReason: 'Place your finger on fingerprint scanner to login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Authenticated')));
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint not recognized')),
          );
        }
      }
    } catch (e, st) {
      // log full error for adb logcat / console
      debugPrint('Fingerprint auth error: $e');
      debugPrint('$st');
      if (mounted) {
        final msg = e.toString();
        final short = msg.length > 120 ? '${msg.substring(0, 120)}...' : msg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fingerprint authentication error: $short')),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HISHAB PRO',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Place your finger on fingerprint scanner to login',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  const Text('Touch the fingerprint sensor.'),
                  const SizedBox(height: 24),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fingerprint,
                        size: 56,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      // go to password screen and replace this fingerprint screen
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PasswordLoginScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Full-screen password login screen
class PasswordLoginScreen extends StatefulWidget {
  const PasswordLoginScreen({super.key});

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final TextEditingController _pwdCtrl = TextEditingController();

  Future<void> _tryLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('app_password') ?? '';
    if (_pwdCtrl.text == stored) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incorrect password')));
  }

  Future<void> _forgotPassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Forgot password?'),
        content: const Text('This will remove the saved password. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_password');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved password cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'HISHAB PRO',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _tryLogin,
                        child: const Text('Login'),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If initialization fails (missing google-services.json / plist), continue
    // and app will run without Firebase features until configured.
    debugPrint('Firebase.initializeApp() failed: $e');
  }

  // MobileAds removed — no initialization

  runApp(const MyApp());
}

// Platform channel for directory picker / storage actions (Android)
final MethodChannel _storageChannel = MethodChannel(
  'com.hishab_pro_new/storage',
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _accounts = [];
  final gsign.GoogleSignIn _googleSignIn = gsign.GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.metadata.readonly',
    ],
  );
  final _nameController = TextEditingController();
  final _editController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  Timer? _autoBackupTimer;
  bool _isAutoBackingUp = false;
  // AdMob banner removed

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadSettings();
    _startAutoBackupScheduler();
    // Ensure a default password exists on first run (default: '1234')
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureDefaultPassword();
      // check for a local JSON restore file (one-off helper used for debugging/import)
      try {
        await _importLocalRestoreIfPresent();
      } catch (_) {}
      await _maybeShowAuth();
    });

    // AdMob removed — no banner initialization
  }

  // One-off helper: import a JSON backup file if present on device.
  // Looks for 'backup_inspect_repaired.json' in app documents and in /sdcard/Download.
  Future<void> _importLocalRestoreIfPresent() async {
    try {
      final candidates = <String>[];
      try {
        final appDoc = await getApplicationDocumentsDirectory();
        candidates.add(p.join(appDoc.path, 'backup_inspect_repaired.json'));
      } catch (_) {}
      candidates.add(
        '/storage/emulated/0/Download/backup_inspect_repaired.json',
      );
      candidates.add(
        p.join(
          (await getTemporaryDirectory()).path,
          'backup_inspect_repaired.json',
        ),
      );

      String? foundPath;
      for (final c in candidates) {
        try {
          final f = File(c);
          if (await f.exists()) {
            foundPath = c;
            break;
          }
        } catch (_) {}
      }
      if (foundPath == null) return;
      final f = File(foundPath);
      final content = await f.readAsString();
      final decoded = jsonDecode(content);
      List<Map<String, dynamic>> accountsList;
      if (decoded is Map && decoded['accounts'] is List) {
        accountsList = (decoded['accounts'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (decoded is List) {
        accountsList = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local restore file has unexpected format'),
          ),
        );
        return;
      }

      setState(() => _accounts = accountsList);
      await _saveAccounts();
      try {
        await f.delete();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local JSON restore applied')),
      );
    } catch (e) {
      // Suppress noisy permission errors when probing common download paths.
      final msg = e.toString();
      if (msg.contains('Permission') ||
          msg.contains('Permission denied') ||
          msg.contains('PathAccessException')) {
        if (kDebugMode) debugPrint('[importLocalRestore] suppressed error: $e');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Local restore failed: $e')));
    }
  }

  Future<void> _ensureDefaultPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('app_password') ?? '';
      if (stored.isEmpty) {
        await prefs.setString('app_password', '1234');
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _maybeShowAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useBiometric = prefs.getBool('unlock_with_fingerprint') ?? false;
      final storedPwd = prefs.getString('app_password') ?? '';
      // If either password or fingerprint is missing, force full-screen setup
      if (!useBiometric || storedPwd.isEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SetupAuthScreen(localAuth: _localAuth),
            fullscreenDialog: true,
          ),
        );
        // After returning from setup, reload settings to pick up the fingerprint flag
        if (mounted) await _loadSettings();
        return;
      }

      if (useBiometric) {
        if (!mounted) return;
        await _showFingerprintLoginDialog();
      } else if (storedPwd.isNotEmpty) {
        if (!mounted) return;
        await _showPasswordLoginDialog();
      }
    } catch (_) {}
  }

  Future<void> _showFingerprintLoginDialog() async {
    // Push full-screen fingerprint login screen
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FingerprintLoginScreen(localAuth: _localAuth),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _showPasswordLoginDialog() async {
    // Push full-screen password login screen
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordLoginScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('currency_symbol');
    if (s != null && s.isNotEmpty) {
      setState(() => appCurrencySymbol = s);
    }
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    // AdMob removed — nothing to dispose
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString('accounts');
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      setState(() {
        _accounts = decoded.map((item) {
          final map = Map<String, dynamic>.from(item);
          final txList =
              (map['transactions'] as List<dynamic>?)
                  ?.map((tx) => Map<String, dynamic>.from(tx))
                  .toList() ??
              [];
          map['transactions'] = txList;
          return map;
        }).toList();
      });
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accounts', jsonEncode(_accounts));
  }

  void _addAccount() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('অ্যাকাউন্টের নাম দিন')));
      return;
    }
    setState(() {
      _accounts.add({
        'name': name,
        'credit': 0.0,
        'debit': 0.0,
        'balance': 0.0,
        'transactions': [],
      });
    });
    _saveAccounts();
    _nameController.clear();
    Navigator.pop(context);
  }

  void _editAccount(int index) {
    _editController.text = _accounts[index]['name'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Account Name'),
        content: TextField(controller: _editController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = _editController.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _accounts[index]['name'] = newName);
                _saveAccounts();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(int index) {
    setState(() => _accounts.removeAt(index));
    _saveAccounts();
  }

  Future<void> _confirmDeleteAccount(int index) async {
    if (!mounted) return;
    final name = (_accounts[index]['name'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text('Are you sure you want to delete account "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _deleteAccount(index);
    }
  }
  // _showTransactionDialog removed — unused helper
  // transaction dialog removed (unused helper)

  void _showSelectAccountDialog() {
    String searchQuery = '';
    String? selectedName;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _accounts
                .where(
                  (acc) => acc['name'].toString().toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ),
                )
                .toList();
            return AlertDialog(
              title: const Text('Select account'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search account',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final acc = filtered[idx];
                          return RadioListTile<String>(
                            title: Text(acc['name']),
                            value: acc['name'],
                            groupValue: selectedName,
                            onChanged: (value) =>
                                setDialogState(() => selectedName = value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedName != null) {
                      final idx = _accounts.indexWhere(
                        (a) => a['name'] == selectedName,
                      );
                      if (idx != -1) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountHistoryScreen(
                              accountIndex: idx,
                              accounts: _accounts,
                              onSave: _saveAccounts,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('VIEW'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- New helpers: totals, multi-color icon, backup & restore ---
  Map<String, double> _computeTotals() {
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    for (final a in _accounts) {
      totalCredit += (a['credit'] as num?)?.toDouble() ?? 0.0;
      totalDebit += (a['debit'] as num?)?.toDouble() ?? 0.0;
    }
    return {
      'credit': totalCredit,
      'debit': totalDebit,
      'balance': totalCredit - totalDebit,
    };
  }

  Widget _multiColorIcon(
    IconData icon,
    List<Color> colors, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final bd = await rootBundle.load('assets/logo.png');
      return bd.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // _backupAccounts removed — unused after UI changes

  // --- Google Drive helpers ---
  http.Client _createAuthClient(Map<String, String> headers) =>
      GoogleAuthClient(headers);

  Future<http.Client?> _getAuthenticatedClient() async {
    try {
      gsign.GoogleSignInAccount? acct;
      try {
        acct = await _googleSignIn.signInSilently();
      } catch (_) {
        acct = null;
      }

      if (acct == null) {
        // Try interactive sign-in
        try {
          acct = await _googleSignIn.signIn();
        } catch (e) {
          acct = null;
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
          }
        }
      }

      if (acct == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in not completed')),
          );
        }
        return null;
      }

      final headers = await acct.authHeaders;
      return _createAuthClient(headers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
      }
      return null;
    }
  }

  Future<void> _uploadToDrive(String fileName, String content) async {
    final client = await _getAuthenticatedClient();
    if (client == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google sign-in failed')));
      return;
    }

    final driveApi = gd.DriveApi(client);
    try {
      // Ensure folder exists
      String folderId = '';
      final folderQuery =
          "name = 'HISHAB PRO' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final folderList = await driveApi.files.list(
        q: folderQuery,
        spaces: 'drive',
        pageSize: 1,
        $fields: 'files(id,name)',
      );
      if (folderList.files != null && folderList.files!.isNotEmpty) {
        folderId = folderList.files!.first.id!;
      } else {
        final folderMeta = gd.File();
        folderMeta.name = 'HISHAB PRO';
        folderMeta.mimeType = 'application/vnd.google-apps.folder';
        final created = await driveApi.files.create(folderMeta);
        folderId = created.id!;
      }

      final fileMeta = gd.File();
      fileMeta.name = fileName;
      fileMeta.parents = [folderId];

      final bytes = utf8.encode(content);
      final media = gd.Media(Stream.value(bytes), bytes.length);
      final createdFile = await driveApi.files.create(
        fileMeta,
        uploadMedia: media,
        $fields: 'id,name',
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Uploaded: ${createdFile.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      client.close();
    }
  }

  Future<void> _showChangeCurrencyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select currency'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '৳'),
            child: const Text('৳ Taka'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '\$'),
            child: const Text('\$ Dollar'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await prefs.setString('currency_symbol', choice);
    if (!mounted) return;
    setState(() => appCurrencySymbol = choice);
  }

  Future<void> _showChangePasswordDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('app_password');
    _currentPasswordController.clear();
    _newPasswordController.clear();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final cur = _currentPasswordController.text;
    final nw = _newPasswordController.text;
    if (nw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password cannot be empty')),
      );
      return;
    }
    if (stored != null && stored.isNotEmpty && stored != cur) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password incorrect')),
      );
      return;
    }
    await prefs.setString('app_password', nw);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password changed')));
  }

  Future<void> _showDriveBackupDialog() async {
    final fileName = '${DateFormat('dd-MM-yyyy').format(DateTime.now())}.db';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup: Select folder'),
        content: const Text(
          'অনুগ্রহ করে আপনার ডিভাইসে একটি "HISHAB PRO" নামের ফোল্ডার তৈরি করুন বা নির্বাচন করুন।\nCONTINUE চাপলে ফাইল সেভ করার জন্য ফোল্ডার নির্বাচন উইন্ডো খুলবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final json = jsonEncode(_accounts);
              _pickDirectoryAndBackup(fileName, json);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectoryAndBackup(String fileName, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? treeUri = prefs.getString('backup_tree_uri');

      if (treeUri == null || treeUri.isEmpty) {
        treeUri = await _storageChannel.invokeMethod<String>('pickDirectory');
      }
      if (treeUri == null || treeUri.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No folder selected')));
        return;
      }

      final bytes = base64Encode(utf8.encode(content));
      final saved = await _storageChannel.invokeMethod<String>(
        'saveToDirectory',
        {'treeUri': treeUri, 'displayName': fileName, 'bytes': bytes},
      );
      try {
        await prefs.setString('backup_tree_uri', treeUri);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally: ${saved ?? fileName}')),
      );

      await _uploadToDrive(fileName, content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _savePrefsBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> dump = {};
      for (final k in prefs.getKeys()) {
        final v = prefs.get(k);
        dump[k] = v;
      }
      final now = DateTime.now();
      final fileName = 'prefs-${DateFormat('dd-MM-yyyy').format(now)}.json';
      final content = jsonEncode(dump);
      // reuse existing pick+save+upload flow
      await _pickDirectoryAndBackup(fileName, content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prefs backup failed: $e')));
    }
  }

  void _startAutoBackupScheduler() {
    // Run periodic checks while the app is active. This schedules an in-app
    // auto-backup once per day between 22:00 and 23:59. It requires the app
    // to be running in foreground or background (not after process killed).
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(const Duration(minutes: 15), (
      timer,
    ) async {
      if (_isAutoBackingUp) return;
      final now = DateTime.now();
      if (now.hour < 22 || now.hour > 23) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool('auto_drive_backup') ?? false;
        if (!enabled) return; // user disabled automatic Drive backups
        final todayKey = DateFormat('yyyy-MM-dd').format(now);
        final lastDone = prefs.getString('last_auto_backup_date') ?? '';
        if (lastDone == todayKey) return; // already backed up today
        _isAutoBackingUp = true;
        final fileName = '${DateFormat('dd-MM-yyyy').format(now)}.JSON';
        final content = jsonEncode({'accounts': _accounts});
        await _uploadToDrive(fileName, content);
        await prefs.setString('last_auto_backup_date', todayKey);
      } catch (_) {
        // ignore errors for scheduler
      } finally {
        _isAutoBackingUp = false;
      }
    });
  }

  Future<void> _showDriveRestoreDialog() async {
    // Ask whether user wants to restore accounts or prefs from Drive
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Restore type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'accounts'),
            child: const Text('Restore accounts from Drive'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'prefs'),
            child: const Text('Restore prefs from Drive'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (kind == null || kind.isEmpty) return;

    final client = await _getAuthenticatedClient();
    if (client == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google sign-in failed')));
      return;
    }
    final driveApi = gd.DriveApi(client);
    try {
      // find folder
      final folderQuery =
          "name = 'HISHAB PRO' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final folderList = await driveApi.files.list(
        q: folderQuery,
        spaces: 'drive',
        pageSize: 1,
        $fields: 'files(id,name)',
      );
      if (folderList.files == null || folderList.files!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No HISHAB PRO folder on Drive')),
        );
        return;
      }
      final folderId = folderList.files!.first.id!;
      final files = await driveApi.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        pageSize: 100,
        $fields: 'files(id,name,modifiedTime)',
      );
      final items = files.files ?? [];
      if (items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backup files found in HISHAB PRO')),
        );
        return;
      }

      // show selection dialog
      if (!mounted) return;
      final choice = await showDialog<gd.File>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select backup to restore'),
          children: items.map((f) {
            final label = '${f.name}';
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Text(label),
            );
          }).toList(),
        ),
      );

      if (choice == null) return;
      // download
      final media =
          await driveApi.files.get(
                choice.id!,
                downloadOptions: gd.DownloadOptions.fullMedia,
              )
              as gd.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      // Try JSON first (accept both Map {'accounts': [...] } and raw List formats)
      try {
        final content = utf8.decode(bytes);
        final decoded = jsonDecode(content);
        if (kind == 'prefs') {
          if (decoded is Map) {
            // Apply prefs
            final prefs = await SharedPreferences.getInstance();
            for (final entry in decoded.entries) {
              final k = entry.key;
              final v = entry.value;
              if (v is bool) {
                await prefs.setBool(k, v);
              } else if (v is int) {
                await prefs.setInt(k, v);
              } else if (v is double) {
                await prefs.setDouble(k, v);
              } else if (v is String) {
                await prefs.setString(k, v);
              } else if (v is List) {
                try {
                  await prefs.setString(k, jsonEncode(v));
                } catch (_) {}
              } else if (v == null) {
                // ignore
              } else {
                try {
                  await prefs.setString(k, jsonEncode(v));
                } catch (_) {}
              }
            }
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prefs restored from Drive')),
            );
            return;
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected file is not a prefs JSON'),
              ),
            );
            return;
          }
        }
        if (decoded is Map && decoded['accounts'] is List) {
          setState(() {
            _accounts = (decoded['accounts'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
          await _saveAccounts();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Restore completed')));
          return;
        }

        if (decoded is List) {
          setState(() {
            _accounts = decoded
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
          await _saveAccounts();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Restore completed')));
          return;
        }
      } catch (_) {
        // not JSON, try sqlite DB below
      }

      // Attempt to treat file as SQLite DB
      try {
        final tempDir = await getTemporaryDirectory();
        final dbPath = p.join(tempDir.path, choice.name ?? 'restore.db');
        final f = File(dbPath);
        await f.writeAsBytes(bytes, flush: true);
        final Database db = await openDatabase(dbPath, readOnly: true);
        try {
          final accRows = await db.query('accounts');
          final List<Map<String, dynamic>> restored = [];
          for (final acc in accRows) {
            final accId = acc['id'];
            final accName = (acc['name'] ?? '').toString();
            final txRows = await db.query(
              'transactions',
              where: 'account_id = ?',
              whereArgs: [accId],
            );
            double creditSum = 0.0;
            double debitSum = 0.0;
            final txs = <Map<String, dynamic>>[];
            for (final t in txRows) {
              final c = ((t['credit'] as num?)?.toDouble() ?? 0.0);
              final d = ((t['debit'] as num?)?.toDouble() ?? 0.0);
              creditSum += c;
              debitSum += d;
              txs.add({
                'date': t['date']?.toString() ?? '',
                'particular': t['particular']?.toString() ?? '',
                'credit': c,
                'debit': d,
              });
            }
            restored.add({
              'name': accName,
              'credit': creditSum,
              'debit': debitSum,
              'balance': creditSum - debitSum,
              'transactions': txs,
            });
          }
          await db.close();
          // set state
          setState(() {
            _accounts = restored;
          });
          await _saveAccounts();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Restore completed')));
          return;
        } finally {
          try {
            await db.close();
          } catch (_) {}
          try {
            await File(dbPath).delete();
          } catch (_) {}
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid backup file')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      client.close();
    }
  }

  // ignore: unused_element
  Future<void> _exportTransactionsToFile({
    required bool asCsv,
    bool asDb = false,
    String? overrideFileName,
  }) async {
    try {
      // Build content
      String content = '';
      final now = DateTime.now();
      final nameStamp = DateFormat('dd-MM-yyyy').format(now);
      // determine file name
      final override = overrideFileName;
      final String fileName =
          override ??
          (asDb
              ? '$nameStamp.db'
              : (asCsv ? '$nameStamp.csv' : '$nameStamp.json'));

      if (asCsv) {
        final sb = StringBuffer();
        // CSV header
        sb.writeln('Account,Date,Particular,Credit,Debit');
        for (final acc in _accounts) {
          final accName = (acc['name'] ?? '').toString().replaceAll(',', ' ');
          final List<dynamic> txs = acc['transactions'] ?? [];
          for (final t in txs) {
            final date = (t['date'] ?? '').toString();
            final particular = (t['particular'] ?? '').toString().replaceAll(
              ',',
              ' ',
            );
            final credit = ((t['credit'] as num?)?.toString() ?? '0');
            final debit = ((t['debit'] as num?)?.toString() ?? '0');
            sb.writeln('$accName,$date,$particular,$credit,$debit');
          }
        }
        content = sb.toString();
      } else if (!asDb) {
        // JSON: export full accounts structure
        content = const JsonEncoder.withIndent(
          '  ',
        ).convert({'accounts': _accounts});
      }

      String savedPath = '';

      if (asDb) {
        // Create a temporary SQLite DB and populate it
        final tempDir = await getTemporaryDirectory();
        final tempDbPath = p.join(tempDir.path, fileName);
        // remove if exists
        try {
          if (await File(tempDbPath).exists()) {
            await File(tempDbPath).delete();
          }
        } catch (_) {}

        final Database db = await openDatabase(
          tempDbPath,
          version: 1,
          onCreate: (Database db, int version) async {
            await db.execute(
              'CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
            );
            await db.execute(
              'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER, date TEXT, particular TEXT, credit REAL, debit REAL)',
            );
          },
        );

        try {
          for (final acc in _accounts) {
            final accName = (acc['name'] ?? '').toString();
            final accId = await db.insert('accounts', {'name': accName});
            final List<dynamic> txs = acc['transactions'] ?? [];
            for (final t in txs) {
              await db.insert('transactions', {
                'account_id': accId,
                'date': (t['date'] ?? '').toString(),
                'particular': (t['particular'] ?? '').toString(),
                'credit': ((t['credit'] as num?)?.toDouble() ?? 0.0),
                'debit': ((t['debit'] as num?)?.toDouble() ?? 0.0),
              });
            }
          }
        } finally {
          await db.close();
        }
      }

      if (Platform.isAndroid) {
        // request storage permission
        try {
          PermissionStatus status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
        } catch (_) {}
        final externalDir = Directory('/storage/emulated/0/HISHAB PRO NEW');
        if (!await externalDir.exists()) {
          try {
            await externalDir.create(recursive: true);
          } catch (_) {}
        }
        final destFile = File('${externalDir.path}/$fileName');
        if (asDb) {
          final tempDir = await getTemporaryDirectory();
          final tempDbPath = p.join(tempDir.path, fileName);
          await destFile.writeAsBytes(await File(tempDbPath).readAsBytes());
          try {
            await File(tempDbPath).delete();
          } catch (_) {}
        } else {
          await destFile.writeAsString(content);
        }
        savedPath = destFile.path;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        if (asDb) {
          final tempDir = await getTemporaryDirectory();
          final tempDbPath = p.join(tempDir.path, fileName);
          await file.writeAsBytes(await File(tempDbPath).readAsBytes());
          try {
            await File(tempDbPath).delete();
          } catch (_) {}
        } else {
          await file.writeAsString(content);
        }
        savedPath = file.path;
      }

      if (!mounted) return;
      // show success and offer share
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export saved'),
          content: Text(savedPath),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                try {
                  share_plus.Share.shareXFiles([
                    share_plus.XFile(savedPath),
                  ], text: 'HISHAB PRO - Export');
                } catch (_) {
                  try {
                    share_plus.Share.share('File: $savedPath');
                  } catch (_) {}
                }
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // _showExportDialog removed — unused helper

  // _restoreAccounts removed — local restore option removed from Dashboard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Custom header: HISHAB PRO with Credit/Debit/Balance card
              Builder(
                builder: (_) {
                  final totals = _computeTotals();
                  String fmtVal(double v) {
                    try {
                      return NumberFormat.decimalPattern(
                        'en_IN',
                      ).format(v.round());
                    } catch (_) {
                      return v.toStringAsFixed(0);
                    }
                  }

                  return Container(
                    color: Colors.transparent,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 220,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF673AB7), Color(0xFF7E57C2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // decorative big rounded accent on the right
                              Positioned(
                                right: -60,
                                top: -40,
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF7E57C2),
                                        Color(0xFF9C27B0),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Rounded label above the icon
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Text(
                                      'HISHAB PRO',
                                      style: TextStyle(
                                        color: Color(0xFF673AB7),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.white,
                                    child: Container(
                                      width: 58,
                                      height: 58,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: FutureBuilder<Uint8List?>(
                                        future: _loadLogoBytes(),
                                        builder: (context, snap) {
                                          if (snap.hasData &&
                                              snap.data != null) {
                                            return CircleAvatar(
                                              radius: 28,
                                              backgroundColor: Colors.white,
                                              backgroundImage: MemoryImage(
                                                snap.data!,
                                              ),
                                            );
                                          }
                                          return const Icon(
                                            Icons.book,
                                            color: Color(0xFF673AB7),
                                            size: 32,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 36.0,
                                    ),
                                    child: Divider(
                                      color: Colors.white70,
                                      thickness: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Removed the small corner logo overlay; centered logo is used instead.
                        Positioned(
                          left: 28,
                          right: 28,
                          bottom: -64,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF673AB7), Color(0xFF7E57C2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Credit
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Credit(+)',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$appCurrencySymbol ${fmtVal(totals['credit'] ?? 0.0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Colors.white24,
                                  height: 14,
                                ),
                                // Debit
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Debit(-)',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$appCurrencySymbol ${fmtVal(totals['debit'] ?? 0.0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Colors.white24,
                                  height: 14,
                                ),
                                // Balance
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Balance',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$appCurrencySymbol ${fmtVal(totals['balance'] ?? 0.0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 110),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 72),
              ListTile(
                leading: _multiColorIcon(Icons.home, [
                  Colors.grey,
                  Colors.blue,
                  Colors.purple,
                ]),
                title: const Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: _multiColorIcon(Icons.cloud_upload, [
                  Colors.orange,
                  Colors.pink,
                  Colors.purple,
                ]),
                title: const Text(
                  'Backup',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Backup options'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDriveBackupDialog();
                          },
                          child: const Text('Backup to Google Drive'),
                        ),
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _savePrefsBackup();
                          },
                          child: const Text('Save prefs backup'),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // 'Restore' (local) option removed from Dashboard per request.
              ListTile(
                leading: _multiColorIcon(Icons.cloud, [
                  Colors.lightBlue,
                  Colors.cyan,
                ]),
                title: const Text(
                  'Restore from Drive',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDriveRestoreDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: _multiColorIcon(Icons.settings, [
                  Colors.brown,
                  Colors.orange,
                  Colors.deepOrange,
                ]),
                title: const Text(
                  'Change currency',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeCurrencyDialog();
                },
              ),
              ListTile(
                leading: _multiColorIcon(Icons.lock, [
                  Colors.indigo,
                  Colors.purple,
                  Colors.blue,
                ]),
                title: const Text(
                  'Change password',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: _multiColorIcon(Icons.security, [
                  Colors.teal,
                  Colors.cyan,
                  Colors.blue,
                ]),
                title: const Text(
                  'Change security question',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: _multiColorIcon(Icons.settings_applications, [
                  Colors.grey,
                  Colors.blueGrey,
                  Colors.black54,
                ]),
                title: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      persistentFooterButtons: null,
      appBar: AppBar(
        title: const Text('হিসাব প্রো'),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSelectAccountDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'Settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                return;
              }
              if (value == 'Security') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SetupAuthScreen(localAuth: _localAuth),
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(value)));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Settings', child: Text('Settings')),
              const PopupMenuItem(value: 'Security', child: Text('Security')),
              const PopupMenuItem(value: 'Backup', child: Text('Backup')),
              const PopupMenuItem(value: 'About', child: Text('About')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _accounts.isEmpty
            ? const Center(
                child: Text(
                  'কোনো অ্যাকাউন্ট নেই\nনতুন যোগ করুন',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.black54),
                ),
              )
            : ListView.builder(
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final acc = _accounts[index];
                  final balance = (acc['balance'] as double?) ?? 0.0;
                  return Card(
                    elevation: 8,
                    shadowColor: Colors.black.withAlpha(102),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {
                        // Tap anywhere on the card opens the account history.
                        debugPrint('[UI] Card tapped: index=$index');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountHistoryScreen(
                              accountIndex: index,
                              accounts: _accounts,
                              onSave: _saveAccounts,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 4.0,
                                    ),
                                    child: Text(
                                      acc['name'],
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                _build3DIconButton(
                                  Icons.edit,
                                  Colors.blue,
                                  () => _editAccount(index),
                                ),
                                _build3DIconButton(
                                  Icons.delete,
                                  Colors.red,
                                  () => _confirmDeleteAccount(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildBox(
                                  'Credit(↑)',
                                  acc['credit'] ?? 0.0,
                                  Colors.green.shade600,
                                ),
                                _buildBox(
                                  'Debit(↓)',
                                  acc['debit'] ?? 0.0,
                                  Colors.red.shade600,
                                ),
                                _buildBox(
                                  'Balance',
                                  balance,
                                  balance >= 0
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _nameController.clear();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              title: const Text('Add new account'),
              content: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account name'),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: _addAccount,
                  child: const Text('SAVE'),
                ),
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFF673AB7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _build3DIconButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
            BoxShadow(
              color: const Color.fromARGB(255, 122, 71, 204).withAlpha(204),
              blurRadius: 6,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildBox(
    String label,
    double value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final child = Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF673AB7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(153),
            blurRadius: 12,
            offset: const Offset(4, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.grey.withAlpha(102),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            '$appCurrencySymbol ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Expanded(
        child: GestureDetector(onTap: onTap, child: child),
      );
    }

    return Expanded(child: child);
  }
}

// ------------------------- Settings Screen -------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _chronological = false;
  bool _backupReminder = false;
  bool _autoDriveBackup = false;
  bool _unlockWithFingerprint = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chronological = prefs.getBool('chronological_sorting') ?? false;
      _backupReminder = prefs.getBool('backup_reminder') ?? false;
      _autoDriveBackup = prefs.getBool('auto_drive_backup') ?? false;
      _unlockWithFingerprint =
          prefs.getBool('unlock_with_fingerprint') ?? false;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget _buildPill({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF673AB7),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _buildPill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chronological Sorting',
                  style: TextStyle(fontSize: 16),
                ),
                Switch(
                  value: _chronological,
                  onChanged: (v) {
                    setState(() => _chronological = v);
                    _setBool('chronological_sorting', v);
                  },
                ),
              ],
            ),
          ),
          _buildPill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Backup reminder', style: TextStyle(fontSize: 16)),
                Switch(
                  value: _backupReminder,
                  onChanged: (v) {
                    setState(() => _backupReminder = v);
                    _setBool('backup_reminder', v);
                  },
                ),
              ],
            ),
          ),
          _buildPill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: const Text(
                        'Auto Google Drive backup (22:00 - 23:59)',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Switch(
                      value: _autoDriveBackup,
                      onChanged: (v) async {
                        setState(() => _autoDriveBackup = v);
                        await _setBool('auto_drive_backup', v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'When enabled the app will automatically upload a backup to your Google Drive between 10:00 PM and 11:59 PM once per day.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          _buildPill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Unlock with fingerprint',
                      style: TextStyle(fontSize: 16),
                    ),
                    Switch(
                      value: _unlockWithFingerprint,
                      onChanged: (v) {
                        setState(() => _unlockWithFingerprint = v);
                        _setBool('unlock_with_fingerprint', v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "When enabled, you'll need to use fingerprint to open Hishab Pro.",
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountHistoryScreen extends StatefulWidget {
  final int accountIndex;
  final List<Map<String, dynamic>> accounts;
  final VoidCallback onSave;

  const AccountHistoryScreen({
    super.key,
    required this.accountIndex,
    required this.accounts,
    required this.onSave,
  });

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  late Map<String, dynamic> account;
  late List<Map<String, dynamic>> transactions;
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _particularFocusNode = FocusNode();
  final TextEditingController particularCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> productList = [];
  String _previousText = '';
  final ScrollController _scrollController = ScrollController();

  // Date filter variables
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  bool _showFilterPanel = false;

  // Search filter variables
  final TextEditingController _amountFilterCtrl = TextEditingController();
  final TextEditingController _particularFilterCtrl = TextEditingController();
  bool _reverseSorting = false;

  // Balance calculation variables
  double _previousBalance = 0.0;
  double _selectedRangeBalance = 0.0;

  void _showWheelDatePicker(
    DateTime initialDate,
    StateSetter setModalState,
    Function(DateTime) onDateSelected,
  ) {
    // Simplified date picker: use platform date picker instead of the custom
    // wheel picker. It returns a DateTime which we pass to the caller.
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ).then((picked) {
      if (picked != null) onDateSelected(picked);
    });
  }

  @override
  void initState() {
    super.initState();
    account = widget.accounts[widget.accountIndex];
    transactions = List<Map<String, dynamic>>.from(
      account['transactions'] ?? [],
    );
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString('products');
    if (json != null) {
      final List<dynamic> decoded = jsonDecode(json);
      setState(() => productList = decoded.cast<String>());
    } else {
      productList = [
        'চাল',
        'ডাল',
        'তেল',
        'চিনি',
        'লবণ',
        'সাবান',
        'মশলা',
        'দুধ',
        'ডিম',
      ];
      _saveProducts();
    }
  }

  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('products', jsonEncode(productList));
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _particularFocusNode.dispose();
    particularCtrl.dispose();
    amountCtrl.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _amountFilterCtrl.dispose();
    _particularFilterCtrl.dispose();
    super.dispose();
  }

  double get totalCredit => (account['credit'] as num?)?.toDouble() ?? 0.0;
  double get totalDebit => (account['debit'] as num?)?.toDouble() ?? 0.0;
  double get balance => (account['balance'] as num?)?.toDouble() ?? 0.0;

  String _fmt(double value) {
    try {
      // Use Indian grouping (lakhs) so 888888 -> 8,88,888
      return NumberFormat.decimalPattern('en_IN').format(value.round());
    } catch (_) {
      return value.toStringAsFixed(0);
    }
  }

  String _fmtMoney(double value) {
    try {
      return NumberFormat('#,##0.00', 'en_IN').format(value);
    } catch (_) {
      return value.toStringAsFixed(2);
    }
  }

  // Robust date parser for transaction date strings
  DateTime? _parseTxDate(String? s) {
    if (s == null) return null;
    final str = s.toString().trim();
    if (str.isEmpty) return null;
    try {
      // common formats used across the app
      return DateFormat('dd-MM-yyyy').parseStrict(str);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(str);
    } catch (_) {}
    try {
      return DateTime.parse(str);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(str);
    } catch (_) {}
    return null;
  }

  // Calculate balance before the selected date range
  double _calculatePreviousBalance() {
    if (_filterFromDate == null) return 0.0;

    double balance = 0.0;
    for (final tx in transactions) {
      try {
        final txDate = _parseTxDate(tx['date']?.toString());
        if (txDate == null) continue;
        if (txDate.isBefore(_filterFromDate!)) {
          final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
          final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
          balance += (credit - debit);
        }
      } catch (_) {
        continue;
      }
    }
    return balance;
  }

  // Calculate balance for the selected date range
  double _calculateSelectedRangeBalance(List<Map<String, dynamic>> filtered) {
    double balance = 0.0;
    for (final tx in filtered) {
      final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
      final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
      balance += (credit - debit);
    }
    return balance;
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    // First filter by date range
    List<Map<String, dynamic>> filtered = transactions;

    if (_filterFromDate != null || _filterToDate != null) {
      filtered = transactions.where((tx) {
        try {
          final txDate = _parseTxDate(tx['date']?.toString());
          if (txDate == null) return true;

          if (_filterFromDate != null && txDate.isBefore(_filterFromDate!)) {
            return false;
          }

          if (_filterToDate != null) {
            final toDateEndOfDay = _filterToDate!.add(const Duration(days: 1));
            if (txDate.isAfter(toDateEndOfDay)) {
              return false;
            }
          }

          return true;
        } catch (_) {
          return true;
        }
      }).toList();
    }

    // Apply reverse sorting (newest first)
    if (_reverseSorting) {
      filtered = filtered.reversed.toList();
    }

    // Calculate balances
    _previousBalance = _calculatePreviousBalance();
    _selectedRangeBalance = _calculateSelectedRangeBalance(filtered);

    // Debug info: print summary to console
    try {
      if (kDebugMode) {
        print(
          '[_getFilteredTransactions] from=$_filterFromDate to=$_filterToDate reverse=$_reverseSorting filtered=${filtered.length} previous=$_previousBalance selected=$_selectedRangeBalance total=${_previousBalance + _selectedRangeBalance}',
        );
        if (filtered.isNotEmpty) {
          final sample = filtered
              .take(3)
              .map(
                (tx) =>
                    '${tx['date']}:${tx['particular']}:${tx['credit'] ?? 0}/${tx['debit'] ?? 0}',
              )
              .join(' | ');
          print('[sample tx] $sample');
        }
      }
    } catch (_) {}

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _filterFromDate = null;
      _filterToDate = null;
      _reverseSorting = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _showFilterPanel = false;
      // Force recalculation and print debug info
      final filtered = _getFilteredTransactions();
      try {
        if (kDebugMode) {
          print(
            '[ApplyFilters] from=$_filterFromDate to=$_filterToDate reverse=$_reverseSorting filtered=${filtered.length} previous=$_previousBalance selected=$_selectedRangeBalance total=${_previousBalance + _selectedRangeBalance}',
          );
        }
      } catch (_) {}
    });
  }

  void _tryCalculateFormula(String text) {
    final trimmed = text.trim();
    // Support formulas with decimals and operators: * / + - x (and ×)
    final RegExp regex = RegExp(
      r"(\d+(?:\.\d+)?)\s*([\*×xX\/+\-])\s*(\d+(?:\.\d+)?)$",
    );
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final left = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final op = match.group(2) ?? '*';
      final right = double.tryParse(match.group(3) ?? '0') ?? 0.0;
      double result;
      switch (op) {
        case '*':
        case '×':
        case 'x':
        case 'X':
          result = left * right;
          break;
        case '/':
          if (right == 0) return;
          result = left / right;
          break;
        case '+':
          result = left + right;
          break;
        case '-':
          result = left - right;
          break;
        default:
          return;
      }

      // Format: if integer result, show without decimals, else keep decimals
      final out = (result % 1 == 0)
          ? result.toStringAsFixed(0)
          : result.toString();
      // Allow zero result too (support 0 explicitly)
      amountCtrl.text = out;
    }
  }

  void _addTransaction() {
    DateTime selectedDate = DateTime.now();
    bool isCredit = true;

    particularCtrl.clear();
    amountCtrl.clear();

    final newProductController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: Colors.transparent,
              body: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                    maxWidth: MediaQuery.of(context).size.width * 0.92,
                  ),
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF673AB7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    'Add transaction',
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Transaction Date : ',
                                      style: TextStyle(
                                        color: const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ),
                                        fontSize: 15,
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showWheelDatePicker(
                                          selectedDate,
                                          setModalState,
                                          (newDate) => setModalState(
                                            () => selectedDate = newDate,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd MMM, yyyy',
                                          ).format(selectedDate),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.amber,
                                            decorationThickness: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _showWheelDatePicker(
                                        selectedDate,
                                        setModalState,
                                        (newDate) => setModalState(
                                          () => selectedDate = newDate,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_drop_down_circle,
                                        color: Colors.amber,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Transaction type :',
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Transform.scale(
                                                    scale: 2.2,
                                                    child: Radio<bool>(
                                                      value: true,
                                                      groupValue: isCredit,
                                                      activeColor: Colors.amber,
                                                      onChanged: (v) {
                                                        if (v != null) {
                                                          setModalState(
                                                            () => isCredit = v,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Credit (+)',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Transform.scale(
                                                    scale: 2.2,
                                                    child: Radio<bool>(
                                                      value: false,
                                                      groupValue: isCredit,
                                                      activeColor: Colors.amber,
                                                      onChanged: (v) {
                                                        if (v != null) {
                                                          setModalState(
                                                            () => isCredit = v,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Debit (-)',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 0),

                                Text(
                                  'Amount :',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 1),

                                TextField(
                                  controller: amountCtrl,
                                  focusNode: _amountFocusNode,
                                  cursorColor: Colors.amber,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: const TextStyle(
                                      color: Color.fromARGB(255, 255, 255, 255),
                                    ),
                                    prefixText: '$appCurrencySymbol ',
                                    prefixStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    border: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Text(
                                  'Particular :',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_drop_down_circle,
                                        color: Colors.amber,
                                        size: 25,
                                      ),
                                      tooltip: 'পণ্য সিলেক্ট করুন',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => StatefulBuilder(
                                            builder: (ctx, setDialogState) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'পণ্য সিলেক্ট করুন',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  height: 280,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: ListView.builder(
                                                          itemCount: productList
                                                              .length,
                                                          itemBuilder: (ctx, idx) {
                                                            final item =
                                                                productList[idx];
                                                            return ListTile(
                                                              dense: true,
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                              contentPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 0,
                                                                  ),
                                                              title: Text(
                                                                item,
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              onLongPress: () {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder: (confirmCtx) => AlertDialog(
                                                                    title: const Text(
                                                                      'ডিলিট করবেন?',
                                                                    ),
                                                                    content: Text(
                                                                      'আপনি কি "$item" ডিলিট করতে চান?',
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () =>
                                                                            Navigator.pop(
                                                                              confirmCtx,
                                                                            ),
                                                                        child: const Text(
                                                                          'না',
                                                                          style: TextStyle(
                                                                            color: Color.fromARGB(
                                                                              255,
                                                                              33,
                                                                              37,
                                                                              252,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed: () {
                                                                          setDialogState(
                                                                            () => productList.removeAt(
                                                                              idx,
                                                                            ),
                                                                          );
                                                                          _saveProducts();
                                                                          Navigator.pop(
                                                                            confirmCtx,
                                                                          );
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                '$item ডিলিট হয়েছে',
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        child: const Text(
                                                                          'হ্যাঁ',
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.red,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                              onTap: () {
                                                                particularCtrl
                                                                        .text =
                                                                    '$item ';
                                                                particularCtrl
                                                                    .selection = TextSelection.fromPosition(
                                                                  TextPosition(
                                                                    offset: particularCtrl
                                                                        .text
                                                                        .length,
                                                                  ),
                                                                );
                                                                setState(() {});
                                                                Navigator.pop(
                                                                  ctx,
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actionsPadding:
                                                    const EdgeInsets.fromLTRB(
                                                      8,
                                                      4,
                                                      8,
                                                      8,
                                                    ),
                                                actions: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: SizedBox(
                                                          width:
                                                              MediaQuery.of(
                                                                context,
                                                              ).size.width *
                                                              0.65,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Expanded(
                                                                child: TextField(
                                                                  controller:
                                                                      newProductController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'নতুন পণ্যের নাম',
                                                                    hintStyle:
                                                                        const TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                    contentPadding:
                                                                        const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              7,
                                                                          vertical:
                                                                              5,
                                                                        ),
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .add_circle,
                                                                  color: Colors
                                                                      .green,
                                                                  size: 30,
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                onPressed: () {
                                                                  final newItem =
                                                                      newProductController
                                                                          .text
                                                                          .trim();
                                                                  if (newItem
                                                                      .isNotEmpty) {
                                                                    if (!productList
                                                                        .contains(
                                                                          newItem,
                                                                        )) {
                                                                      setDialogState(
                                                                        () => productList.add(
                                                                          newItem,
                                                                        ),
                                                                      );
                                                                      _saveProducts();
                                                                      newProductController
                                                                          .clear();
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            'পণ্য যোগ হয়েছে: $newItem',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    } else {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            'এই পণ্য আগেই আছে',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                          'বন্ধ করুন',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: particularCtrl,
                                        focusNode: _particularFocusNode,
                                        cursorColor: Colors.amber,
                                        keyboardType: TextInputType.text,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        maxLines: 2,
                                        minLines: 1,
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'বিবরণ / পণ্য',
                                          hintStyle: const TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              255,
                                              255,
                                              255,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 0,
                                              ),
                                          border: const UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.amber,
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Colors.amber,
                                                  width: 2,
                                                ),
                                              ),
                                          focusedBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Colors.amber,
                                                  width: 2,
                                                ),
                                              ),
                                        ),
                                        onChanged: (value) {
                                          if (value.length >
                                              _previousText.length) {
                                            _tryCalculateFormula(value);
                                          }
                                          _previousText = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(186, 128, 33, 218),
                            border: Border(
                              top: BorderSide(
                                color: Color.fromARGB(186, 128, 33, 218),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final amount =
                                        double.tryParse(
                                          amountCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final particular = particularCtrl.text
                                        .trim();

                                    if (amount < 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'পরিমাণ ০ বা তার বেশি হতে হবে',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final newTx = {
                                      'date': DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(selectedDate),
                                      'particular': particular.isEmpty
                                          ? (isCredit ? 'Credit' : 'Debit')
                                          : particular,
                                      'credit': isCredit ? amount : 0.0,
                                      'debit': isCredit ? 0.0 : amount,
                                    };

                                    setState(() {
                                      if (isCredit) {
                                        account['credit'] =
                                            (account['credit'] ?? 0.0) + amount;
                                        account['balance'] =
                                            (account['balance'] ?? 0.0) +
                                            amount;
                                      } else {
                                        account['debit'] =
                                            (account['debit'] ?? 0.0) + amount;
                                        account['balance'] =
                                            (account['balance'] ?? 0.0) -
                                            amount;
                                      }
                                      transactions.add(newTx);
                                      account['transactions'] = transactions;
                                    });

                                    widget.onSave();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Transaction added successfully',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: const Color.fromARGB(
                                      255,
                                      145,
                                      55,
                                      230,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'ADD',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionForm({int? editIndex}) {
    DateTime selectedDate = DateTime.now();
    bool isCredit = true;

    particularCtrl.clear();
    amountCtrl.clear();

    if (editIndex != null &&
        editIndex >= 0 &&
        editIndex < transactions.length) {
      final tx = transactions[editIndex];
      // Try parse date from stored formats
      final dateStr = (tx['date'] ?? '').toString();
      try {
        selectedDate = DateFormat('dd-MM-yyyy').parse(dateStr);
      } catch (_) {
        try {
          selectedDate = DateTime.parse(dateStr);
        } catch (_) {
          selectedDate = DateTime.now();
        }
      }
      final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
      final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
      isCredit = credit > 0;
      particularCtrl.text = tx['particular'] ?? '';
      amountCtrl.text = (isCredit ? credit : debit).toStringAsFixed(0);
    }

    final newProductController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: Colors.transparent,
              body: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                    maxWidth: MediaQuery.of(context).size.width * 0.92,
                  ),
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF673AB7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    editIndex == null
                                        ? 'Add transaction'
                                        : 'Edit transaction',
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Transaction Date : ',
                                      style: TextStyle(
                                        color: const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ),
                                        fontSize: 15,
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showWheelDatePicker(
                                          selectedDate,
                                          setModalState,
                                          (newDate) => setModalState(
                                            () => selectedDate = newDate,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd MMM, yyyy',
                                          ).format(selectedDate),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.amber,
                                            decorationThickness: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _showWheelDatePicker(
                                        selectedDate,
                                        setModalState,
                                        (newDate) => setModalState(
                                          () => selectedDate = newDate,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_drop_down_circle,
                                        color: Colors.amber,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Transaction type :',
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Transform.scale(
                                                    scale: 2.2,
                                                    child: Radio<bool>(
                                                      value: true,
                                                      groupValue: isCredit,
                                                      activeColor: Colors.amber,
                                                      onChanged: (v) {
                                                        if (v != null) {
                                                          setModalState(
                                                            () => isCredit = v,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Credit (+)',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Transform.scale(
                                                    scale: 2.2,
                                                    child: Radio<bool>(
                                                      value: false,
                                                      groupValue: isCredit,
                                                      activeColor: Colors.amber,
                                                      onChanged: (v) {
                                                        if (v != null) {
                                                          setModalState(
                                                            () => isCredit = v,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Debit (-)',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 0),

                                Text(
                                  'Amount :',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 1),

                                TextField(
                                  controller: amountCtrl,
                                  focusNode: _amountFocusNode,
                                  cursorColor: Colors.amber,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: const TextStyle(
                                      color: Color.fromARGB(255, 255, 255, 255),
                                    ),
                                    prefixText: '$appCurrencySymbol ',
                                    prefixStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    border: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.amber,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Text(
                                  'Particular :',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_drop_down_circle,
                                        color: Colors.amber,
                                        size: 25,
                                      ),
                                      tooltip: 'পণ্য সিলেক্ট করুন',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => StatefulBuilder(
                                            builder: (ctx, setDialogState) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'পণ্য সিলেক্ট করুন',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  height: 280,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: ListView.builder(
                                                          itemCount: productList
                                                              .length,
                                                          itemBuilder: (ctx, idx) {
                                                            final item =
                                                                productList[idx];
                                                            return ListTile(
                                                              dense: true,
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                              contentPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 0,
                                                                  ),
                                                              title: Text(
                                                                item,
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              onLongPress: () {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder: (confirmCtx) => AlertDialog(
                                                                    title: const Text(
                                                                      'ডিলিট করবেন?',
                                                                    ),
                                                                    content: Text(
                                                                      'আপনি কি "$item" ডিলিট করতে চান?',
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () =>
                                                                            Navigator.pop(
                                                                              confirmCtx,
                                                                            ),
                                                                        child: const Text(
                                                                          'না',
                                                                          style: TextStyle(
                                                                            color: Color.fromARGB(
                                                                              255,
                                                                              33,
                                                                              37,
                                                                              252,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed: () {
                                                                          setDialogState(
                                                                            () => productList.removeAt(
                                                                              idx,
                                                                            ),
                                                                          );
                                                                          _saveProducts();
                                                                          Navigator.pop(
                                                                            confirmCtx,
                                                                          );
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                '$item ডিলিট হয়েছে',
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        child: const Text(
                                                                          'হ্যাঁ',
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.red,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                              onTap: () {
                                                                particularCtrl
                                                                        .text =
                                                                    '$item ';
                                                                particularCtrl
                                                                    .selection = TextSelection.fromPosition(
                                                                  TextPosition(
                                                                    offset: particularCtrl
                                                                        .text
                                                                        .length,
                                                                  ),
                                                                );
                                                                setState(() {});
                                                                Navigator.pop(
                                                                  ctx,
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actionsPadding:
                                                    const EdgeInsets.fromLTRB(
                                                      8,
                                                      4,
                                                      8,
                                                      8,
                                                    ),
                                                actions: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: SizedBox(
                                                          width:
                                                              MediaQuery.of(
                                                                context,
                                                              ).size.width *
                                                              0.65,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Expanded(
                                                                child: TextField(
                                                                  controller:
                                                                      newProductController,
                                                                  decoration: InputDecoration(
                                                                    hintText:
                                                                        'নতুন পণ্যের নাম',
                                                                    hintStyle:
                                                                        const TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                        ),
                                                                    contentPadding:
                                                                        const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              7,
                                                                          vertical:
                                                                              5,
                                                                        ),
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons
                                                                      .add_circle,
                                                                  color: Colors
                                                                      .green,
                                                                  size: 30,
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                onPressed: () {
                                                                  final newItem =
                                                                      newProductController
                                                                          .text
                                                                          .trim();
                                                                  if (newItem
                                                                      .isNotEmpty) {
                                                                    if (!productList
                                                                        .contains(
                                                                          newItem,
                                                                        )) {
                                                                      setDialogState(
                                                                        () => productList.add(
                                                                          newItem,
                                                                        ),
                                                                      );
                                                                      _saveProducts();
                                                                      newProductController
                                                                          .clear();
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            'পণ্য যোগ হয়েছে: $newItem',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    } else {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            'এই পণ্য আগেই আছে',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                          'বন্ধ করুন',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: particularCtrl,
                                        focusNode: _particularFocusNode,
                                        cursorColor: Colors.amber,
                                        keyboardType: TextInputType.text,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                        maxLines: 2,
                                        minLines: 1,
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'বিবরণ / পণ্য',
                                          hintStyle: const TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              255,
                                              255,
                                              255,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 0,
                                              ),
                                          border: const UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.amber,
                                              width: 2,
                                            ),
                                          ),
                                          enabledBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Colors.amber,
                                                  width: 2,
                                                ),
                                              ),
                                          focusedBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: Colors.amber,
                                                  width: 2,
                                                ),
                                              ),
                                        ),
                                        onChanged: (value) {
                                          if (value.length >
                                              _previousText.length) {
                                            _tryCalculateFormula(value);
                                          }
                                          _previousText = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(186, 128, 33, 218),
                            border: Border(
                              top: BorderSide(
                                color: Color.fromARGB(186, 128, 33, 218),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final amount =
                                        double.tryParse(
                                          amountCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final particular = particularCtrl.text
                                        .trim();

                                    if (amount < 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'পরিমাণ ০ বা তার বেশি হতে হবে',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final newTx = {
                                      'date': DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(selectedDate),
                                      'particular': particular.isEmpty
                                          ? (isCredit ? 'Credit' : 'Debit')
                                          : particular,
                                      'credit': isCredit ? amount : 0.0,
                                      'debit': isCredit ? 0.0 : amount,
                                    };

                                    setState(() {
                                      if (editIndex == null) {
                                        if (isCredit) {
                                          account['credit'] =
                                              (account['credit'] ?? 0.0) +
                                              amount;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) +
                                              amount;
                                        } else {
                                          account['debit'] =
                                              (account['debit'] ?? 0.0) +
                                              amount;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) -
                                              amount;
                                        }
                                        transactions.add(newTx);
                                      } else {
                                        // adjust totals based on previous values
                                        final prev = transactions[editIndex];
                                        final prevCredit =
                                            (prev['credit'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final prevDebit =
                                            (prev['debit'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        if (prevCredit > 0) {
                                          account['credit'] =
                                              (account['credit'] ?? 0.0) -
                                              prevCredit;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) -
                                              prevCredit;
                                        } else if (prevDebit > 0) {
                                          account['debit'] =
                                              (account['debit'] ?? 0.0) -
                                              prevDebit;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) +
                                              prevDebit;
                                        }

                                        if (isCredit) {
                                          account['credit'] =
                                              (account['credit'] ?? 0.0) +
                                              amount;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) +
                                              amount;
                                        } else {
                                          account['debit'] =
                                              (account['debit'] ?? 0.0) +
                                              amount;
                                          account['balance'] =
                                              (account['balance'] ?? 0.0) -
                                              amount;
                                        }

                                        transactions[editIndex] = newTx;
                                      }
                                      account['transactions'] = transactions;
                                    });

                                    widget.onSave();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Transaction saved successfully',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: const Color.fromARGB(
                                      255,
                                      145,
                                      55,
                                      230,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    editIndex == null ? 'ADD' : 'SAVE',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int index) {
    final tx = transactions[index];
    final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
    final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'এই ট্রানজেকশন পারমানেন্টভাবে মুছে যাবে। আপনি কি নিশ্চিত?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (credit > 0) {
                  account['credit'] = (account['credit'] ?? 0.0) - credit;
                  account['balance'] = (account['balance'] ?? 0.0) - credit;
                } else if (debit > 0) {
                  account['debit'] = (account['debit'] ?? 0.0) - debit;
                  account['balance'] = (account['balance'] ?? 0.0) + debit;
                }
                transactions.removeAt(index);
                account['transactions'] = transactions;
              });
              widget.onSave();
              Navigator.pop(confirmCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction deleted successfully'),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTxOptions(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(0),
        content: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransactionForm(editIndex: index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(index);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  static const MethodChannel _pdfChannel = MethodChannel(
    'com.hishab_pro_new/pdf',
  );

  Future<void> _saveTransactionsAsPdf() async {
    try {
      // prepare font (try Bengali font asset, fallback to default)
      pw.Font baseFont;
      try {
        final fontData = await rootBundle.load(
          'assets/fonts/NotoSansBengali-Regular.ttf',
        );
        baseFont = pw.Font.ttf(fontData.buffer.asByteData());
      } catch (_) {
        baseFont = pw.Font.helvetica();
      }

      // prepare totals and signed strings
      // totals available: totalCredit and totalDebit

      // Use currently filtered transactions (respect search, date range, reverse)
      final filtered = _getFilteredTransactions();

      // Compute totals for the filtered set
      final double pdfTotalCredit = filtered.fold<double>(0.0, (acc, t) {
        return acc + ((t['credit'] as num?)?.toDouble() ?? 0.0);
      });
      final double pdfTotalDebit = filtered.fold<double>(0.0, (acc, t) {
        return acc + ((t['debit'] as num?)?.toDouble() ?? 0.0);
      });

      // The effective balance for the PDF should reflect the filtered range
      final double pdfBalance = _previousBalance + _selectedRangeBalance;

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          margin: pw.EdgeInsets.all(0),
          pageFormat: pdf.PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: baseFont),
          header: (pw.Context ctx) {
            return pw.Container(
              height: 72,
              color: pdf.PdfColors.deepPurple,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // 3D-style SAT logo: two layered rectangles for depth and 'SAT' text
                  pw.Container(
                    width: 56,
                    height: 56,
                    child: pw.Stack(
                      children: [
                        pw.Positioned(
                          left: 6,
                          top: 8,
                          child: pw.Container(
                            width: 48,
                            height: 48,
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(8),
                              color: pdf.PdfColors.blue900,
                            ),
                          ),
                        ),
                        pw.Positioned(
                          left: 0,
                          top: 0,
                          child: pw.Container(
                            width: 48,
                            height: 48,
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(8),
                              color: pdf.PdfColors.cyan400,
                              boxShadow: [
                                pw.BoxShadow(
                                  color: pdf.PdfColors.grey600,
                                  offset: pdf.PdfPoint(2, 2),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                'SAT',
                                style: pw.TextStyle(
                                  color: pdf.PdfColors.white,
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(
                        '${(account['name'] ?? 'MD KARIM').toString().toUpperCase()} - Transaction History',
                        style: pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              height: 36,
              color: pdf.PdfColors.grey300,
              alignment: pw.Alignment.center,
              child: pw.Text(
                'HISHAB PRO — ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10),
              ),
            );
          },
          build: (pw.Context ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color: pdf.PdfColors.white,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 6),
                  // Right-aligned label for Debit/Credit history
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Container()),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: pdf.PdfColor.fromInt(0xFF4B2E83),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'DEBIT/CREDIT HISTORY',
                          style: pw.TextStyle(
                            color: pdf.PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    color: pdf.PdfColors.white,
                    child: pw.Table.fromTextArray(
                      border: pw.TableBorder.all(
                        color: pdf.PdfColors.grey300,
                        width: 1,
                      ),
                      headers: [
                        '#',
                        'Date',
                        'Particular',
                        'Debit(Tk)',
                        'Credit(Tk)',
                      ],
                      data: filtered.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final tx = entry.value;
                        final credit =
                            (tx['credit'] as num?)?.toDouble() ?? 0.0;
                        final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
                        return [
                          (idx + 1).toString(),
                          tx['date'] ?? '',
                          tx['particular'] ?? '',
                          debit > 0 ? debit.toStringAsFixed(0) : '',
                          credit > 0 ? credit.toStringAsFixed(0) : '',
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: pdf.PdfColors.white,
                      ),
                      cellStyle: pw.TextStyle(fontSize: 10),
                      // Right-align numeric columns (Debit, Credit)
                      cellAlignments: {
                        3: pw.Alignment.centerRight,
                        4: pw.Alignment.centerRight,
                      },
                      headerDecoration: pw.BoxDecoration(
                        color: pdf.PdfColor.fromInt(0xFF4B2E83),
                      ),
                      cellAlignment: pw.Alignment.centerLeft,
                      columnWidths: {
                        0: const pw.FlexColumnWidth(0.8),
                        1: const pw.FlexColumnWidth(2.0),
                        2: const pw.FlexColumnWidth(5.0),
                        3: const pw.FlexColumnWidth(2.0),
                        4: const pw.FlexColumnWidth(2.0),
                      },
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // Totals row styled like the image (purple background, totals on right)
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: pdf.PdfColor.fromInt(0xFF4B2E83),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total',
                          style: pw.TextStyle(
                            color: pdf.PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              color: pdf.PdfColor.fromInt(0xFF4B2E83),
                              child: pw.Text(
                                _fmtMoney(pdfTotalDebit),
                                style: pw.TextStyle(
                                  color: pdf.PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              color: pdf.PdfColor.fromInt(0xFF4B2E83),
                              child: pw.Text(
                                _fmtMoney(pdfTotalCredit),
                                style: pw.TextStyle(
                                  color: pdf.PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: pdf.PdfColor.fromInt(0xFF3A2470),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Balance',
                          style: pw.TextStyle(
                            color: pdf.PdfColors.white,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          pdfBalance < 0
                              ? '-${_fmtMoney(pdfBalance.abs())}'
                              : _fmtMoney(pdfBalance),
                          style: pw.TextStyle(
                            color: pdf.PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      // Build filename: ACCOUNT NAME (uppercase, spaces allowed) + _DDMMYYYY.PDF
      final accountLabel = (account['name'] ?? 'MD KARIM')
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r"[^A-Za-z0-9 _-]"), '');
      final outFileName =
          '${accountLabel}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf';
      // Prefer saving via MediaStore on Android (compatible with scoped storage)
      String savedPath = '';
      if (Platform.isAndroid) {
        try {
          final base64Data = base64Encode(bytes);
          final res = await _pdfChannel.invokeMethod('savePdf', {
            'bytes': base64Data,
            'displayName': outFileName,
            'mimeType': 'application/pdf',
          });
          if (res is String) savedPath = res;
        } catch (e) {
          // fallback: try writing to external path if MediaStore failed
        }
      }

      // If not saved by MediaStore, fall back to legacy external path write
      if (savedPath.isEmpty) {
        // Request storage permission on Android before writing to external path
        if (Platform.isAndroid) {
          PermissionStatus status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission required to save PDF'),
              ),
            );
            return;
          }
        }

        final externalDir = Directory('/storage/emulated/0/HISHAB PRO NEW');
        if (!await externalDir.exists()) {
          try {
            await externalDir.create(recursive: true);
          } catch (_) {
            // fallback to app external dir
          }
        }

        final file = File('${externalDir.path}/$outFileName');
        await file.writeAsBytes(bytes);
        savedPath = file.path;
      }

      // Show success dialog with path and share option
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Successfully'),
          content: Text('/document/raw:$savedPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // If savedPath is a content URI, share from memory bytes; otherwise share file path
                if (savedPath.startsWith('content://')) {
                  final x = share_plus.XFile.fromData(
                    bytes,
                    name: outFileName,
                    mimeType: 'application/pdf',
                  );
                  share_plus.Share.shareXFiles([
                    x,
                  ], text: 'HISHAB PRO - Transaction History PDF');
                } else {
                  share_plus.Share.shareXFiles([
                    share_plus.XFile(savedPath),
                  ], text: 'HISHAB PRO - Transaction History PDF');
                }
              },
              child: const Text('SHARE'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            account['name'] ?? 'অজানা',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              onPressed: _addTransaction,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showFilterPanel
                      ? Colors.white
                      : const Color(0xFF673AB7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.search,
                  color: _showFilterPanel
                      ? const Color(0xFF673AB7)
                      : Colors.white,
                  size: 24,
                ),
              ),
              onPressed: () {
                setState(() {
                  _showFilterPanel = !_showFilterPanel;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'save_pdf') {
                  await _saveTransactionsAsPdf();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save_pdf',
                  child: Text('Save as PDF'),
                ),
              ],
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RawScrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(4),
        thumbColor: Colors.transparent,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // Filter Panel
              if (_showFilterPanel)
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reverse Sorting Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _reverseSorting,
                            onChanged: (value) {
                              setState(() {
                                _reverseSorting = value ?? false;
                                // Recalculate immediately so list & balances update
                                _getFilteredTransactions();
                              });
                            },
                            activeColor: const Color(0xFF673AB7),
                          ),
                          const Text(
                            'Reverse Sorting',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // From Date Field
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterFromDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _filterFromDate = picked;
                              // Recalculate immediately so balance box updates live
                              _getFilteredTransactions();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _filterFromDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_filterFromDate!)
                                      : 'From date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _filterFromDate != null
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // To Date Field
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterToDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _filterToDate = picked;
                              // Recalculate immediately so balance box updates live
                              _getFilteredTransactions();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _filterToDate != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_filterToDate!)
                                      : 'To date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _filterToDate != null
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Balance Display
                      if (_filterFromDate != null || _filterToDate != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF673AB7),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Smart Reverse Sorting',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF673AB7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Previous Balance:'),
                                  Text(
                                    '$appCurrencySymbol ${_fmt(_previousBalance.abs())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _previousBalance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Range Balance:'),
                                  Text(
                                    '$appCurrencySymbol ${_fmt(_selectedRangeBalance.abs())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedRangeBalance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$appCurrencySymbol ${_fmt((_previousBalance + _selectedRangeBalance).abs())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color:
                                          (_previousBalance +
                                                  _selectedRangeBalance) >=
                                              0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _clearFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade400,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('CLEAR'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _applyFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF673AB7),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('APPLY'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0.0,
                  vertical: 8,
                ),
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2.3),
                    1: FlexColumnWidth(4.1),
                    2: FlexColumnWidth(2.3),
                    3: FlexColumnWidth(2.3),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 4, 6, 4),
                          child: Text(
                            'Date',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          child: Text(
                            'Particular',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          child: Text(
                            'Credit(Tk)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(6, 4, 0, 4),
                          child: Text(
                            'Debit(Tk)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    ..._getFilteredTransactions().asMap().entries.map((entry) {
                      final index = entry.key;
                      final tx = entry.value;
                      final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
                      final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
                      final bool isCredit = credit > 0;
                      final Color rowColor = isCredit
                          ? Colors.green
                          : (debit > 0 ? Colors.red : Colors.black87);
                      return TableRow(
                        decoration: BoxDecoration(
                          color: index % 2 == 0
                              ? Colors.white
                              : const Color(0xFFF7F7F7),
                        ),
                        children: [
                          InkWell(
                            onTap: () => _showTxOptions(index),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                              child: Text(
                                tx['date'] ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: rowColor,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showTxOptions(index),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  tx['particular'] ?? '',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: rowColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showTxOptions(index),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  credit > 0 ? _fmt(credit) : '',
                                  style: TextStyle(
                                    color: rowColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showTxOptions(index),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  debit > 0 ? _fmt(debit) : '',
                                  style: TextStyle(
                                    color: rowColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),

                    // totals row removed from table; totals are shown in fixed footer below
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Credit(↑)',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        '$appCurrencySymbol ${_fmt(totalCredit)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Debit(↓)',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      '$appCurrencySymbol ${_fmt(totalDebit)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        '$appCurrencySymbol ${_fmt(balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
