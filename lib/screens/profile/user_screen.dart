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

    if (userProfile == null) {
      setState(() {
        _userProfile = null;
        _isLoggedIn = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _userProfile = Map<String, dynamic>.from(userProfile);
        _isLoggedIn = true;
        _isLoading = false;
      });
    }
  } catch (e) {
    // error ดึงข้อมูล
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
    // สามารถเพิ่มฟิลด์อื่น ๆ จาก _userProfile ได้ตามต้องการ

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
              // กลับไปหน้า login หรือหน้าแรกถ้าต้องการ
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ฟีเจอร์กำลังพัฒนา')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
