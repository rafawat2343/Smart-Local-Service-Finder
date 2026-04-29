import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String mapPhoneAuthError(FirebaseAuthException error) {
    final msg = (error.message ?? '').toLowerCase();

    if (msg.contains('billing_not_occured') ||
        msg.contains('billing') ||
        error.code == 'internal-error') {
      return 'Phone OTP is blocked because Firebase billing is not configured. '
          'Enable billing for your Firebase project and try again.';
    }
    if (error.code == 'operation-not-allowed') {
      return 'Phone authentication is not enabled in Firebase Console.';
    }
    if (error.code == 'invalid-phone-number') {
      return 'Invalid phone number format.';
    }
    if (error.code == 'too-many-requests') {
      return 'Too many OTP requests. Please wait and try again.';
    }
    if (error.code == 'quota-exceeded') {
      return 'OTP quota exceeded for this Firebase project.';
    }
    if (error.code == 'app-not-authorized') {
      return 'This app is not authorized for Firebase phone auth. Check SHA keys and package name.';
    }
    return error.message ?? 'Failed to send OTP code.';
  }

  static String _phoneToPseudoEmail(String phoneNumber) {
    final e164 = toBangladeshE164(phoneNumber);
    final key = e164.replaceAll('+', '');
    return '$key@local-service.com';
  }

  static String toBangladeshE164(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('880') && digits.length >= 12) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length == 11) {
      return '+88$digits';
    }
    if (!digits.startsWith('0') && digits.length == 10) {
      return '+880$digits';
    }
    if (input.startsWith('+')) {
      return input;
    }
    throw Exception(
      'Invalid phone number format. Use a valid Bangladesh mobile number.',
    );
  }

  // Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream of authentication state changes
  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Register/Sign Up with phone and password
  static Future<User?> signup({
    required String phoneNumber,
    required String password,
    required String displayName,
  }) async {
    try {
      final email = _phoneToPseudoEmail(phoneNumber);
      final current = _auth.currentUser;

      if (current != null &&
          current.providerData.any((p) => p.providerId == 'phone')) {
        try {
          final UserCredential linkedCredential = await current
              .linkWithCredential(
                EmailAuthProvider.credential(email: email, password: password),
              );

          final User linkedUser = linkedCredential.user ?? current;
          await linkedUser.updateDisplayName(displayName);
          await linkedUser.reload();
          return _auth.currentUser;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            await current.updateDisplayName(displayName);
            await current.reload();
            return _auth.currentUser;
          } else if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            throw Exception(
              'An account already exists with this phone number.',
            );
          } else {
            rethrow;
          }
        }
      }

      try {
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(email: email, password: password);
        final User? user = userCredential.user;
        await user?.updateDisplayName(displayName);
        await user?.reload();
        return _auth.currentUser;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists — sign in with existing credentials
          final UserCredential existing = await _auth
              .signInWithEmailAndPassword(email: email, password: password);
          return existing.user;
        } else if (e.code == 'weak-password') {
          throw Exception('The password provided is too weak.');
        } else {
          throw Exception(e.message ?? 'Registration failed');
        }
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration failed');
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Sign In with phone and password
  static Future<User?> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final email = _phoneToPseudoEmail(phoneNumber);
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception(
              'Connection timed out. Please check your internet connection and try again.',
            ),
          );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No account found with this phone number.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.code == 'invalid-credential' ||
          e.code == 'invalid-email' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw Exception(
            'Incorrect phone number or password. Please try again.');
      } else {
        throw Exception(e.message ?? 'Login failed');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  static Future<User?> registerWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
    required String displayName,
  }) {
    return signup(
      phoneNumber: phoneNumber,
      password: password,
      displayName: displayName,
    );
  }

  static Future<User?> signInWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
  }) {
    return login(phoneNumber: phoneNumber, password: password);
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
        await user.reload();
      }
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  // Check if user is authenticated
  static bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Get current user email
  static String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  // Get current user display name
  static String? getCurrentUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Password reset email failed: $e');
    }
  }

  // Verify phone number with OTP (optional method for future enhancement)
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onVerificationIdReceived,
    required Function(FirebaseAuthException) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          onVerificationIdReceived(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      throw Exception('Phone verification failed: $e');
    }
  }

  static Future<void> startPhoneSignIn({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    required void Function(UserCredential credential) onAutoVerified,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final normalized = toBangladeshE164(phoneNumber);

    await _auth.verifyPhoneNumber(
      phoneNumber: normalized,
      forceResendingToken: forceResendingToken,
      timeout: timeout,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        onAutoVerified(result);
      },
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<UserCredential> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid OTP code. Please try again.');
      }
      if (e.code == 'session-expired') {
        throw Exception('OTP session expired. Please request a new code.');
      }
      throw Exception(e.message ?? 'OTP verification failed.');
    }
  }
}
