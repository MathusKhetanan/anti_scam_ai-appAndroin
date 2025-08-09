import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

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

  // ===================== Validators =====================
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอกอีเมล';
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return 'กรุณากรอกอีเมลให้ถูกต้อง';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (value.length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasDigit = value.contains(RegExp(r'[0-9]'));
    if (!hasUpper || !hasLower || !hasDigit) {
      return 'รหัสผ่านต้องมีตัวพิมพ์ใหญ่ เล็ก และตัวเลข';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
    if (value != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  // ===================== Firestore Helper =====================
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final ref = _firestore.collection('users').doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'provider': user.providerData.isNotEmpty
              ? user.providerData[0].providerId
              : 'email',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isEmailVerified': user.emailVerified,
        });
      } else {
        await ref.update({'lastLoginAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
    }
  }

  // ===================== Register with Email =====================
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showErrorSnackBar('กรุณายอมรับข้อกำหนดและเงื่อนไข');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null && mounted) {
        await user.sendEmailVerification();
        await _saveUserToFirestore(user);
        _showSuccessDialog(email);
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== Register with Google =====================
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Web ใช้ popup
        final provider = GoogleAuthProvider();
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        if (cred.user != null && mounted) {
          await _saveUserToFirestore(cred.user!);
          await _showSuccessAndNavigate();
        }
        return;
      }

      // Android/iOS ใช้ google_sign_in v6.3.0
      final googleSignIn = gsi.GoogleSignIn(scopes: ['email', 'profile']);
      await googleSignIn.signOut(); // บังคับขึ้นหน้าบัญชีเสมอ

      final gsi.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // ผู้ใช้กดยกเลิก
        return;
      }

      final gsi.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken, // v6 ยังมีให้ใช้
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCred.user != null && mounted) {
        await _saveUserToFirestore(userCred.user!);
        _showSuccessSnackBar('สมัครสมาชิกด้วย Google สำเร็จ!');
        await _showSuccessAndNavigate();
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== UI Helpers =====================
  Future<void> _showSuccessAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _showSuccessDialog(String email) {
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
              email,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            const Text('กรุณาตรวจสอบอีเมลและกดยืนยันก่อนเข้าสู่ระบบ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/login');
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
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password, TextTheme textTheme) {
    int strength = 0;
    final reqs = <String>[];

    if (password.length >= 8) strength++; else reqs.add('อย่างน้อย 8 ตัวอักษร');
    if (password.contains(RegExp(r'[A-Z]'))) strength++; else reqs.add('ตัวพิมพ์ใหญ่');
    if (password.contains(RegExp(r'[a-z]'))) strength++; else reqs.add('ตัวพิมพ์เล็ก');
    if (password.contains(RegExp(r'[0-9]'))) strength++; else reqs.add('ตัวเลข');

    Color color;
    String label;
    switch (strength) {
      case 0:
      case 1:
        color = Colors.red;
        label = 'อ่อนแอ';
        break;
      case 2:
        color = Colors.orange;
        label = 'ปานกลาง';
        break;
      case 3:
        color = Colors.amber[700]!;
        label = 'ดี';
        break;
      default:
        color = Colors.green;
        label = 'แข็งแกร่ง';
    }

    if (password.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ความแข็งแกร่ง: ',
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              Text(label,
                  style: textTheme.bodySmall?.copyWith(
                      color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          if (reqs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ต้องการ: ${reqs.join(', ')}',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('สมัครสมาชิก',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_outlined,
                      size: 60, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'สร้างบัญชีใหม่',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกข้อมูลเพื่อสมัครสมาชิก',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 32),

              // Email
              TextFormField(
                controller: _emailController,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  hintText: 'กรอกอีเมลของคุณ',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Password
              TextFormField(
                controller: _passwordController,
                validator: _validatePassword,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  hintText: 'สร้างรหัสผ่านที่แข็งแกร่ง',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
              ),
              _buildPasswordStrengthIndicator(
                  _passwordController.text, textTheme),
              const SizedBox(height: 20),

              // Confirm Password
              TextFormField(
                controller: _confirmController,
                validator: _validateConfirmPassword,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน',
                  hintText: 'กรอกรหัสผ่านอีกครั้ง',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onFieldSubmitted: (_) => _register(),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // Terms
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('ฉันยอมรับ ',
                              style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.8))),
                          InkWell(
                            onTap: _showTermsOfService,
                            child: Text('ข้อกำหนดและเงื่อนไข',
                                style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                )),
                          ),
                          Text(' และ ',
                              style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.8))),
                          InkWell(
                            onTap: _showPrivacyPolicy,
                            child: Text('นโยบายความเป็นส่วนตัว',
                                style: textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              _isLoading
                  ? Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
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
                            label: const Text('สมัครสมาชิก'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.dividerColor)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('หรือ',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6))),
                            ),
                            Expanded(child: Divider(color: theme.dividerColor)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _signUpWithGoogle,
                            icon: Image.asset(
                              'assets/google_icon.png',
                              height: 20,
                              width: 20,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.g_mobiledata,
                                      color: theme.colorScheme.primary),
                            ),
                            label: const Text('สมัครด้วย Google'),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Login link
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
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

  // ===================== Extra Pages =====================
  void _showTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }
}

// ---------------- Terms of Service ----------------
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ข้อกำหนดและเงื่อนไข')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ข้อกำหนดและเงื่อนไขการใช้บริการ',
                style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            Text(
              'วันที่มีผลบังคับใช้: '
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _section('1. การยอมรับข้อกำหนด',
                'การใช้บริการของเราหมายความว่าคุณยอมรับและตกลงที่จะปฏิบัติตามข้อกำหนดและเงื่อนไขเหล่านี้ทั้งหมด หากคุณไม่ยอมรับข้อกำหนดใดๆ กรุณาหยุดการใช้บริการทันที',
                textTheme),
            _section('2. การใช้บริการ',
                '• ต้องมีอายุอย่างน้อย 13 ปี\n'
                '• รับผิดชอบบัญชีและรหัสผ่านของคุณ\n'
                '• ห้ามใช้ในทางที่ผิดกฎหมายหรือไม่เหมาะสม',
                textTheme),
            _section('3. ความเป็นส่วนตัวของข้อมูล',
                'การเก็บ ใช้ และเปิดเผยข้อมูลเป็นไปตามนโยบายความเป็นส่วนตัว',
                textTheme),
            _section('4. การระงับและยกเลิกบัญชี',
                'เราอาจระงับ/ยกเลิกบัญชีหากฝ่าฝืนเงื่อนไข โดยไม่ต้องแจ้งล่วงหน้า',
                textTheme),
            _section('5. ข้อจำกัดความรับผิดชอบ',
                'ไม่รับผิดชอบต่อความเสียหายจากการใช้หรือไม่สามารถใช้บริการ',
                textTheme),
            _section('6. การแก้ไขข้อกำหนด',
                'เราอาจแก้ไขข้อกำหนดได้ตลอดเวลา และมีผลเมื่อเผยแพร่',
                textTheme),
            _section('7. กฎหมายที่ใช้บังคับ',
                'อยู่ภายใต้กฎหมายของประเทศไทย', textTheme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body,
              style: textTheme.bodyMedium
                  ?.copyWith(color: Colors.black54, height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------- Privacy Policy ----------------
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('นโยบายความเป็นส่วนตัว')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('นโยบายความเป็นส่วนตัว',
                style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            Text(
              'วันที่มีผลบังคับใช้: '
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            _section('1. ข้อมูลที่เราเก็บรวบรวม',
                '• ข้อมูลส่วนบุคคล (อีเมล ชื่อ)\n'
                '• ข้อมูลการใช้งานแอป\n'
                '• ข้อมูลอุปกรณ์', textTheme),
            _section('2. วิธีการใช้ข้อมูลของคุณ',
                '• ให้บริการและปรับปรุงระบบ\n'
                '• ส่งการแจ้งเตือนที่จำเป็น\n'
                '• วิเคราะห์การใช้งาน', textTheme),
            _section('3. การแชร์ข้อมูลกับบุคคลที่สาม',
                'เราไม่ขาย/เช่าข้อมูล เว้นแต่ได้รับความยินยอมหรือเพื่อปฏิบัติตามกฎหมาย',
                textTheme),
            _section('4. ความปลอดภัยของข้อมูล',
                'ใช้มาตรการรักษาความปลอดภัยที่เหมาะสม', textTheme),
            _section('5. สิทธิของคุณ',
                'เข้าถึง/แก้ไข/ลบ/ถอนความยินยอม/ร้องเรียนได้', textTheme),
            _section('6. คุกกี้และเทคโนโลยีติดตาม',
                'ใช้เพื่อปรับปรุงประสบการณ์และจดจำการตั้งค่า', textTheme),
            _section('7. การเปลี่ยนแปลงนโยบาย',
                'อาจปรับปรุงและแจ้งให้ทราบตามความเหมาะสม', textTheme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body,
              style: textTheme.bodyMedium
                  ?.copyWith(color: Colors.black54, height: 1.5)),
        ],
      ),
    );
  }
}
