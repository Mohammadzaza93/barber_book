import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  /// Dedicated secondary app used to provision staff logins.
  FirebaseApp? _staffApp;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return cred.user;
  }

  /// Creates an account from the login screen and signs the user in.
  Future<User?> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user;
  }

  /// Creates a staff login without disturbing the owner's active session.
  Future<String> createStaffAccount(String email, String password) async {
    final app = await _staffAppInstance();
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'لم يتم إنشاء الحساب',
        );
      }
      return user.uid;
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  Future<FirebaseApp> _staffAppInstance() async {
    final existing = _staffApp;
    if (existing != null) return existing;
    try {
      return _staffApp = Firebase.app('barberbook-staff-provisioning');
    } on FirebaseException {
      return _staffApp = await Firebase.initializeApp(
        name: 'barberbook-staff-provisioning',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
