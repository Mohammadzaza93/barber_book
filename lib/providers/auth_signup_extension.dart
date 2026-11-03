import 'auth_provider.dart';

/// Public self-registration is disabled for this single-salon app.
/// Accountants are provisioned only by the owner via [AuthProvider.addStaffAccount].
extension AuthProviderSignUp on AuthProvider {
  @Deprecated('Self-registration disabled')
  Future<bool> signUp(String email, String password) async {
    error = 'self-registration-disabled';
    return false;
  }
}
