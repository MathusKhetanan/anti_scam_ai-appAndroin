import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userProfile;

  // Controllers for editing profile
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatusAndFetchProfile();
  }

  Future<void> _checkLoginStatusAndFetchProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
      return;
    }

    try {
final userProfile = await supabase
    .from('profiles')
    .select()
    .eq('id', user.id)
    .single();


      if (userProfile != null) {
        _userProfile = Map<String, dynamic>.from(userProfile);
        // Set controller values for editing
        _fullNameController.text = _userProfile?['full_name'] ?? '';
        _phoneController.text = _userProfile?['phone'] ?? '';
        _dobController.text = _userProfile?['dob'] != null
            ? (_userProfile!['dob'] as String).split('T').first
            : '';
        _addressController.text = _userProfile?['address'] ?? '';
      }

      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userProfile = null;
        _isLoggedIn = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    setState(() {
      _isLoggedIn = false;
      _userProfile = null;
    });
  }

  Future<void> _updateProfileData(String userId, Map<String, dynamic> profileData) async {
final response = await supabase
    .from('profiles')
    .update(profileData)
    .eq('id', userId); // ✅ ไม่ต้องใช้ .execute()


    if (response.error != null) {
      print('Failed to update profile: ${response.error!.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตข้อมูลล้มเหลว: ${response.error!.message}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตข้อมูลเรียบร้อยแล้ว')),
      );
      await _checkLoginStatusAndFetchProfile();
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('แก้ไขข้อมูลโปรไฟล์'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _dobController,
                  decoration: const InputDecoration(labelText: 'วันเกิด (YYYY-MM-DD)'),
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'ที่อยู่'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = supabase.auth.currentUser;
                if (user == null) return;

                final updatedData = {
                  'full_name': _fullNameController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'dob': _dobController.text.trim(),
                  'address': _addressController.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                };

                Navigator.pop(context); // ปิด dialog ก่อนอัปเดต

                await _updateProfileData(user.id, updatedData);
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('โปรไฟล์ผู้ใช้'),
          centerTitle: true,
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('เข้าสู่ระบบ'),
          ),
        ),
      );
    }

    final userName = _userProfile?['full_name'] ?? supabase.auth.currentUser!.email!;
    final userEmail = supabase.auth.currentUser!.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้ใช้'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await _logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ออกจากระบบเรียบร้อย')),
              );
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              child: Text(
                userName.isNotEmpty ? userName[0] : '',
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              userEmail,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('แก้ไขข้อมูล'),
              onPressed: _showEditProfileDialog,
            ),
          ],
        ),
      ),
    );
  }
}
