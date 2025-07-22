import 'package:flutter/material.dart';
import 'package:backendless_sdk/backendless_sdk.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      BackendlessUser user = BackendlessUser()
        ..email = email
        ..password = password;

      await Backendless.userService.register(user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );

      // TODO: นำทางไปหน้าอื่น เช่น หน้าล็อกอิน หรือหน้า Home
      // Navigator.pushReplacementNamed(context, '/login');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'อีเมล'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value == null || !value.contains('@') ? 'อีเมลไม่ถูกต้อง' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                obscureText: true,
                validator: (value) => value != null && value.length >= 6
                    ? null
                    : 'รหัสผ่านต้องมากกว่า 6 ตัวอักษร',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่าน'),
                obscureText: true,
                validator: (value) =>
                    value == _passwordController.text ? null : 'รหัสผ่านไม่ตรงกัน',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('สมัครสมาชิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
