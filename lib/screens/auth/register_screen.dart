import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกอีเมล';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'กรุณากรอกอีเมลให้ถูกต้อง';
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกรหัสผ่าน';
    }
    
    if (value.length < 8) {
      return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    }
    
    // ตรวจสอบความแข็งแกร่งของรหัสผ่าน
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!hasUppercase || !hasLowercase || !hasDigits) {
      return 'รหัสผ่านต้องมีตัวพิมพ์ใหญ่ เล็ก และตัวเลข';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณายืนยันรหัสผ่าน';
    }
    
    if (value != _passwordController.text) {
      return 'รหัสผ่านไม่ตรงกัน';
    }
    
    return null;
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'provider': user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
        });
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      _showErrorSnackBar('กรุณายอมรับข้อกำหนดและเงื่อนไข');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // สร้างบัญชีผู้ใช้
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null && mounted) {
        // ส่งอีเมลยืนยัน
        await user.sendEmailVerification();
        
        // บันทึกข้อมูลใน Firestore
        await _saveUserToFirestore(user);
        
        // แสดงข้อความสำเร็จ
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'อีเมลนี้มีบัญชีอยู่แล้ว กรุณาใช้อีเมลอื่น';
          break;
        case 'weak-password':
          errorMessage = 'รหัสผ่านไม่ปลอดภัยพอ';
          break;
        case 'invalid-email':
          errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        case 'operation-not-allowed':
          errorMessage = 'การสมัครสมาชิกถูกปิดใช้งานชั่วคราว';
          break;
        default:
          errorMessage = 'เกิดข้อผิดพลาด: ${e.message}';
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดบางอย่าง กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null && mounted) {
        await _saveUserToFirestore(userCredential.user!);
        _showSuccessSnackBar('สมัครสมาชิกด้วย Google สำเร็จ!');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการสมัครด้วย Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsOfServiceScreen(),
      ),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            const Text('สมัครสมาชิกสำเร็จ!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เราได้ส่งอีเมลยืนยันไปที่:'),
            const SizedBox(height: 8),
            Text(
              _emailController.text.trim(),
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            const Text('กรุณาตรวจสอบกล่องขาเข้าและกดลิงก์ยืนยันก่อนเข้าสู่ระบบ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ปิด dialog
              Navigator.pushReplacementNamed(context, '/login'); // ไปหน้า login
            },
            child: const Text('ไปหน้าเข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    List<String> requirements = [];
    
    if (password.length >= 8) {
      strength++;
    } else {
      requirements.add('อย่างน้อย 8 ตัวอักษร');
    }
    
    if (password.contains(RegExp(r'[A-Z]'))) {
      strength++;
    } else {
      requirements.add('ตัวพิมพ์ใหญ่');
    }
    
    if (password.contains(RegExp(r'[a-z]'))) {
      strength++;
    } else {
      requirements.add('ตัวพิมพ์เล็ก');
    }
    
    if (password.contains(RegExp(r'[0-9]'))) {
      strength++;
    } else {
      requirements.add('ตัวเลข');
    }

    Color strengthColor;
    String strengthText;
    
    switch (strength) {
      case 0:
      case 1:
        strengthColor = Colors.red;
        strengthText = 'อ่อนแอ';
        break;
      case 2:
        strengthColor = Colors.orange;
        strengthText = 'ปานกลาง';
        break;
      case 3:
        strengthColor = Colors.yellow[700]!;
        strengthText = 'ดี';
        break;
      case 4:
        strengthColor = Colors.green;
        strengthText = 'แข็งแกร่ง';
        break;
      default:
        strengthColor = Colors.grey;
        strengthText = '';
    }

    return password.isNotEmpty ? Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ความแข็งแกร่ง: ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                strengthText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
          ),
          if (requirements.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ต้องการ: ${requirements.join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    ) : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'สมัครสมาชิก',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.iconTheme,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'สร้างบัญชีใหม่',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกข้อมูลเพื่อสมัครสมาชิก',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email Field
              TextFormField(
                controller: _emailController,
                style: textTheme.bodyMedium,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  labelStyle: textTheme.bodySmall,
                  hintText: 'กรอกอีเมลของคุณ',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!, width: 1),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Password Field
              TextFormField(
                controller: _passwordController,
                style: textTheme.bodyMedium,
                validator: _validatePassword,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  labelStyle: textTheme.bodySmall,
                  hintText: 'สร้างรหัสผ่านที่แข็งแกร่ง',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!, width: 1),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                onChanged: (value) => setState(() {}), // เพื่อให้ strength indicator อัปเดต
              ),
              
              // Password Strength Indicator
              _buildPasswordStrengthIndicator(_passwordController.text),
              const SizedBox(height: 20),

              // Confirm Password Field
              TextFormField(
                controller: _confirmController,
                style: textTheme.bodyMedium,
                validator: _validateConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน',
                  labelStyle: textTheme.bodySmall,
                  hintText: 'กรอกรหัสผ่านอีกครั้ง',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!, width: 1),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),

              // Terms & Conditions Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                      child: RichText(
                        text: TextSpan(
                          text: 'ฉันยอมรับ',
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _showTermsOfService,
                                child: Text(
                                  'ข้อกำหนดและเงื่อนไข',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                              text: ' และ ',
                              style: textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _showPrivacyPolicy,
                                child: Text(
                                  'นโยบายความเป็นส่วนตัว',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Register Button or Loading
              _isLoading
                  ? Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'กำลังสมัครสมาชิก...',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _register,
                            icon: const Icon(Icons.person_add, size: 20),
                            label: const Text(
                              'สมัครสมาชิก',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'หรือ',
                                style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: theme.dividerColor)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Sign Up Button
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: Container(
                              padding: const EdgeInsets.all(2),
                              child: Image.asset(
                                'assets/google_icon.png',
                                height: 20,
                                width: 20,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.g_mobiledata,
                                    size: 24,
                                    color: theme.colorScheme.primary,
                                  );
                                },
                              ),
                            ),
                            label: Text(
                              'สมัครด้วย Google',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _signUpWithGoogle,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: theme.dividerColor, width: 1.5),
                              backgroundColor: theme.colorScheme.surface,
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Login Link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: RichText(
                    text: TextSpan(
                      text: 'มีบัญชีอยู่แล้ว? ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      children: [
                        TextSpan(
                          text: 'เข้าสู่ระบบ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// หน้าข้อกำหนดและเงื่อนไข
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อกำหนดและเงื่อนไข'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อกำหนดและเงื่อนไขการใช้บริการ',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'วันที่มีผลบังคับใช้: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. การยอมรับข้อกำหนด',
              'การใช้บริการของเราหมายความว่าคุณยอมรับและตกลงที่จะปฏิบัติตามข้อกำหนดและเงื่อนไขเหล่านี้ทั้งหมด หากคุณไม่ยอมรับข้อกำหนดใดๆ กรุณาหยุดการใช้บริการทันที',
              textTheme,
            ),

            _buildSection(
              '2. การใช้บริการ',
              '''• คุณต้องมีอายุอย่างน้อย 13 ปีในการใช้บริการนี้
• คุณรับผิดชอบในการรักษาความปลอดภัยของบัญชีและรหัสผ่านของคุณ
• ห้ามใช้บริการเพื่อวัตถุประสงค์ที่ผิดกฎหมายหรือไม่เหมาะสม
• ห้ามแชร์หรือเผยแพร่เนื้อหาที่ละเมิดลิขสิทธิ์หรือสิทธิของผู้อื่น''',
              textTheme,
            ),

            _buildSection(
              '3. ความเป็นส่วนตัวของข้อมูล',
              'เราให้ความสำคัญกับความเป็นส่วนตัวของข้อมูลของคุณ การเก็บรวบรวม ใช้ และเปิดเผยข้อมูลส่วนบุคคลของคุณจะเป็นไปตามนโยบายความเป็นส่วนตัวของเรา',
              textTheme,
            ),

            _buildSection(
              '4. การระงับและยกเลิกบัญชี',
              'เราสงวนสิทธิ์ในการระงับหรือยกเลิกบัญชีของคุณหากพบว่ามีการใช้บริการที่ผิดเงื่อนไข โดยไม่ต้องแจ้งให้ทราบล่วงหน้า',
              textTheme,
            ),

            _buildSection(
              '5. ข้อจำกัดความรับผิดชอบ',
              'เราไม่รับผิดชอบต่อความเสียหายใดๆ ที่เกิดขึ้นจากการใช้หรือไม่สามารถใช้บริการ รวมถึงความเสียหายทางอ้อม อุบัติเหตุ หรือความเสียหายพิเศษ',
              textTheme,
            ),

            _buildSection(
              '6. การแก้ไขข้อกำหนด',
              'เราขอสงวนสิทธิ์ในการแก้ไขข้อกำหนดและเงื่อนไขเหล่านี้ได้ตลอดเวลา การแก้ไขจะมีผลทันทีเมื่อได้เผยแพร่บนแพลตฟอร์มของเรา',
              textTheme,
            ),

            _buildSection(
              '7. กฎหมายที่ใช้บังคับ',
              'ข้อกำหนดและเงื่อนไขนี้จะอยู่ภายใต้กฎหมายของประเทศไทย และข้อพิพาทใดๆ จะต้องระงับด้วยการไกล่เกลี่ยหรือฟ้องร้องในศาลไทย',
              textTheme,
            ),

            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ติดต่อเรา',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หากคุณมีคำถามเกี่ยวกับข้อกำหนดและเงื่อนไขนี้ กรุณาติดต่อเราที่:\n\nอีเมล: support@yourapp.com\nโทรศัพท์: 02-xxx-xxxx',
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// หน้านโยบายความเป็นส่วนตัว
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('นโยบายความเป็นส่วนตัว'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'นโยบายความเป็นส่วนตัว',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'วันที่มีผลบังคับใช้: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. ข้อมูลที่เราเก็บรวบรวม',
              '''เราเก็บรวบรวมข้อมูลเพื่อให้บริการที่ดีที่สุดแก่คุณ ได้แก่:

• ข้อมูลส่วนบุคคล: ชื่อ, อีเมล, หมายเลขโทรศัพท์
• ข้อมูลการใช้งาน: วิธีการใช้แอป, ความถี่การใช้งาน
• ข้อมูลอุปกรณ์: รุ่นอุปกรณ์, ระบบปฏิบัติการ, IP Address
• ข้อมูลตำแหน่ง: เมื่อคุณอนุญาตให้เราเข้าถึง''',
              textTheme,
            ),

            _buildSection(
              '2. วิธีการใช้ข้อมูลของคุณ',
              '''เราใช้ข้อมูลของคุณเพื่อ:

• ให้บริการและปรับปรุงประสบการณ์การใช้งาน
• ส่งการแจ้งเตือนและข้อมูลสำคัญ
• วิเคราะห์การใช้งานเพื่อพัฒนาบริการ
• ป้องกันการใช้งานที่ไม่เหมาะสมหรือผิดกฎหมาย
• ปฏิบัติตามข้อกำหนดทางกฎหมาย''',
              textTheme,
            ),

            _buildSection(
              '3. การแชร์ข้อมูลกับบุคคลที่สาม',
              '''เราจะไม่ขาย เช่า หรือแลกเปลี่ยนข้อมูลส่วนบุคคลของคุณกับบุคคลที่สาม ยกเว้น:

• เมื่อได้รับความยินยอมจากคุณ
• เพื่อปฏิบัติตามกฎหมายหรือคำสั่งศาล
• เพื่อป้องกันการฉ้อโกงหรือความเสียหายต่อบริการ
• กับผู้ให้บริการที่เชื่อถือได้ซึ่งช่วยในการดำเนินงาน''',
              textTheme,
            ),

            _buildSection(
              '4. ความปลอดภัยของข้อมูล',
              'เราใช้มาตรการรักษาความปลอดภัยที่เหมาะสมในการปกป้องข้อมูลของคุณ รวมถึงการเข้ารหัส การควบคุมการเข้าถึง และการตรวจสอบความปลอดภัยอย่างสม่ำเสมอ',
              textTheme,
            ),

            _buildSection(
              '5. สิทธิของคุณ',
              '''คุณมีสิทธิ์ในการ:

• เข้าถึงข้อมูลส่วนบุคคลของคุณ
• แก้ไขหรือลบข้อมูลที่ไม่ถูกต้อง
• ถอนความยินยอมการใช้ข้อมูล
• ขอรับสำเนาข้อมูลของคุณ
• ร้องเรียนต่อหน่วยงานกำกับดูแล''',
              textTheme,
            ),

            _buildSection(
              '6. คุกกี้และเทคโนโลยีติดตาม',
              'เราใช้คุกกี้และเทคโนโลยีที่คล้ายกันเพื่อปรับปรุงประสบการณ์การใช้งานของคุณ วิเคราะห์การใช้งาน และจัดเก็บการตั้งค่าของคุณ',
              textTheme,
            ),

            _buildSection(
              '7. การเปลี่ยนแปลงนโยบาย',
              'เราอาจอัปเดตนโยบายความเป็นส่วนตัวนี้เป็นครั้งคราว การเปลี่ยนแปลงที่สำคัญจะมีการแจ้งให้คุณทราบผ่านแอปหรืออีเมล',
              textTheme,
            ),

            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ติดต่อเจ้าหน้าที่คุ้มครองข้อมูล',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หากคุณมีคำถามเกี่ยวกับนโยบายความเป็นส่วนตัวหรือการใช้ข้อมูลของคุณ กรุณาติดต่อ:\n\nอีเมล: privacy@yourapp.com\nโทรศัพท์: 02-xxx-xxxx\nที่อยู่: xxx ถนนxxx เขตxxx กรุงเทพฯ xxxxx',
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}