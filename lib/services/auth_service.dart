import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return cred.user;
  }

  Future<User?> register(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
