import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // เพิ่ม Firestore

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUserToFirestore(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'provider': user.providerData.isNotEmpty ? user.providerData[0].providerId : 'unknown',
      });
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null && mounted) {
        await _saveUserToFirestore(user);
        await _showSuccessAndNavigate();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar('เข้าสู่ระบบล้มเหลว: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดบางอย่าง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);

        if (userCredential.user != null && mounted) {
          await _saveUserToFirestore(userCredential.user!);
          await _showSuccessAndNavigate();
        }
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null && mounted) {
          await _saveUserToFirestore(userCredential.user!);
          await _showSuccessAndNavigate();
        }
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _showSuccessAndNavigate() async {
  if (!mounted) return;

  // แสดง Dialog แจ้งเตือน
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('เข้าสู่ระบบสำเร็จ'),
      content: const Text('คุณได้เข้าสู่ระบบเรียบร้อยแล้ว'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );

  // เมื่อกดตกลงแล้วเปลี่ยนหน้าไป /home
  Navigator.pushReplacementNamed(context, '/home');
}


  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isDark ? Colors.red[400] : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('เข้าสู่ระบบ', style: textTheme.titleLarge),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'อีเมล',
                labelStyle: textTheme.bodySmall,
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'รหัสผ่าน',
                labelStyle: textTheme.bodySmall,
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/reset-password'),
                child: Text(
                  'ลืมรหัสผ่าน?',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text('กำลังเข้าสู่ระบบ...', style: textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                          child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          icon: Image.asset(
                            theme.brightness == Brightness.dark
                                ? 'assets/google_icon.png'
                                : 'assets/google_icon.png',
                            height: 24,
                          ),
                          label: Text(
                            'เข้าสู่ระบบด้วย Google',
                            style: textTheme.bodyMedium,
                          ),
                          onPressed: _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  'ยังไม่มีบัญชี? สมัครสมาชิก',
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
