import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'auth_provider.dart';

/// Login-screen registration (keeps the large auth_provider file unchanged).
extension AuthProviderSignUp on AuthProvider {
  /// Creates a Firebase Auth account and signs the user in.
  ///
  /// After success the auth stream resolves the shop:
  /// - owner email → setup wizard if no shop yet
  /// - other emails → no-access until the owner links members/{uid}
  Future<bool> signUp(String email, String password) async {
    error = null;
    try {
      await AuthService.instance.signUp(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
