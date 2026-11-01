import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  /// Dedicated secondary app used to provision staff logins.
  ///
  /// `createUserWithEmailAndPassword` signs the new user in. Doing that on the
  /// default app would sign the owner out, so staff creation happens on a
  /// second named app. The app is intentionally kept for the rest of the
  /// process lifetime (deleting it races with in-flight calls and makes the
  /// next call slower); only the *session* on that app is cleared.
  FirebaseApp? _staffApp;

  // Resolved lazily on purpose. `FirebaseAuth.instance` throws [core/no-app]
  // when the app was not initialized, and this singleton is constructed while
  // the provider tree is built, before the config error screen can be shown.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return cred.user;
  }

  /// Creates a staff login without disturbing the owner's active session.
  ///
  /// Returns the new uid. Membership under `shops/{shopId}/members/{uid}` is
  /// written by the caller (the owner) — never by this method.
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
      // Never leave the provisioned account signed in on the secondary app.
      try {
        await auth.signOut();
      } catch (_) {
        // Best-effort: the secondary session is isolated from the owner's.
      }
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
