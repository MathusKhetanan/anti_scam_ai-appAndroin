import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isUpdating = false;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;

  // Controllers for editing profile
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _statsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkLoginStatusAndFetchProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _statsController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatusAndFetchProfile() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        _setLoadingState(false, false);
        return;
      }

      // Fetch data in parallel for better performance
      final results = await Future.wait([
        _firestore.collection('profiles').doc(user.uid).get(),
        _firestore.collection('user_stats').doc(user.uid).get(),
      ]);

      final profileSnapshot = results[0];
      final statsSnapshot = results[1];

      if (profileSnapshot.exists) {
        _userProfile = profileSnapshot.data() as Map<String, dynamic>?;
        _populateControllers();
      }

      _userStats = statsSnapshot.exists 
        ? statsSnapshot.data() as Map<String, dynamic>?
        : _getDefaultStats();

      _setLoadingState(false, true);
      _startAnimations();
    } catch (e) {
      _handleError('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      _setLoadingState(false, true);
    }
  }

  void _populateControllers() {
    _fullNameController.text = _userProfile?['full_name'] ?? '';
    _phoneController.text = _userProfile?['phone'] ?? '';
    _dobController.text = _userProfile?['dob'] ?? '';
    _addressController.text = _userProfile?['address'] ?? '';
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'total_scans': 0,
      'scam_detected': 0,
      'last_scan_date': null,
      'reports_submitted': 0,
    };
  }

  void _setLoadingState(bool isLoading, bool isLoggedIn) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
        _isLoggedIn = isLoggedIn;
      });
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _statsController.forward();
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await _showConfirmDialog(
      title: 'ออกจากระบบ',
      content: 'คุณต้องการออกจากระบบหรือไม่?',
      confirmText: 'ออกจากระบบ',
      isDestructive: true,
    );

    if (shouldLogout == true) {
      try {
        await _auth.signOut();
        _resetUserData();
        _showSuccessSnackBar('ออกจากระบบเรียบร้อย');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        _handleError('เกิดข้อผิดพลาดในการออกจากระบบ: $e');
      }
    }
  }

  void _resetUserData() {
    setState(() {
      _isLoggedIn = false;
      _userProfile = null;
      _userStats = null;
    });
  }

  Future<void> _updateProfileData(String userId, Map<String, dynamic> profileData) async {
    setState(() => _isUpdating = true);
    
    try {
      await _firestore.collection('profiles').doc(userId).set(
        {
          ...profileData,
          'email': _auth.currentUser?.email,
          'user_id': userId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
      
      _showSuccessSnackBar('อัปเดตข้อมูลเรียบร้อยแล้ว');
      await _checkLoginStatusAndFetchProfile();
    } catch (e) {
      _handleError('อัปเดตข้อมูลล้มเหลว: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildEditProfileDialog(),
    );
  }

  Widget _buildEditProfileDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildValidatedTextField(
                        controller: _fullNameController,
                        label: 'ชื่อ-นามสกุล',
                        icon: Icons.person,
                        validator: (value) => _validateName(value),
                      ),
                      const SizedBox(height: 16),
                      _buildValidatedTextField(
                        controller: _phoneController,
                        label: 'เบอร์โทรศัพท์',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) => _validatePhone(value),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        hintText: 'เช่น 0812345678',
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(),
                      const SizedBox(height: 16),
                      _buildValidatedTextField(
                        controller: _addressController,
                        label: 'ที่อยู่',
                        icon: Icons.location_on,
                        maxLines: 3,
                        validator: (value) => _validateAddress(value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDialogActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.edit,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'แก้ไขข้อมูลโปรไฟล์',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(),
      child: AbsorbPointer(
        child: _buildValidatedTextField(
          controller: _dobController,
          label: 'วันเกิด',
          icon: Icons.calendar_today,
          validator: (value) => null, // Optional field
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: _dobController.text.isNotEmpty 
          ? DateTime.tryParse(_dobController.text) ?? DateTime.now()
          : DateTime.now(),
        firstDate: DateTime(1950),
        lastDate: DateTime.now(),
      );
      
      if (date != null) {
        _dobController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }
    } catch (e) {
      debugPrint('Error selecting date: $e');
      _handleError('เกิดข้อผิดพลาดในการเลือกวันที่');
    }
  }

  Widget _buildDialogActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isUpdating ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ยกเลิก'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: _isUpdating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final updatedData = {
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'dob': _dobController.text.trim(),
      'address': _addressController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    Navigator.pop(context);
    await _updateProfileData(user.uid, updatedData);
  }

  // Validation methods
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกชื่อ-นามสกุล';
    }
    if (value.trim().length < 2) {
      return 'ชื่อต้องมีอย่างน้อย 2 ตัวอักษร';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกเบอร์โทรศัพท์';
    }
    
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.length != 10) {
      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
    }
    
    if (!cleanPhone.startsWith('0')) {
      return 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 0';
    }
    
    final validPrefixes = ['08', '09', '06', '02'];
    final prefix = cleanPhone.substring(0, 2);
    
    if (!validPrefixes.contains(prefix)) {
      return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
    }
    
    return null;
  }

  String? _validateAddress(String? value) {
    if (value != null && value.trim().isNotEmpty && value.trim().length < 10) {
      return 'ที่อยู่ต้องมีอย่างน้อย 10 ตัวอักษร';
    }
    return null;
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChangingPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline),
              SizedBox(width: 8),
              Text('เปลี่ยนรหัสผ่าน'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'รหัสผ่านปัจจุบัน',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'รหัสผ่านใหม่',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'กรุณากรอกรหัสผ่านใหม่';
                    if (value!.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'ยืนยันรหัสผ่านใหม่',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'รหัสผ่านไม่ตรงกัน';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChangingPassword ? null : () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: isChangingPassword ? null : () async {
                if (!formKey.currentState!.validate()) return;
                
                setDialogState(() => isChangingPassword = true);
                
                try {
                  final user = _auth.currentUser;
                  final credential = EmailAuthProvider.credential(
                    email: user!.email!,
                    password: currentPasswordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  
                  Navigator.pop(context);
                  _showSuccessSnackBar('เปลี่ยนรหัสผ่านเรียบร้อย');
                } catch (e) {
                  _handleError('เกิดข้อผิดพลาด: $e');
                } finally {
                  setDialogState(() => isChangingPassword = false);
                }
              },
              child: isChangingPassword
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('เปลี่ยนรหัสผ่าน'),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation handlers with error handling
  void _navigateToHistory() {
  Navigator.pushNamed(context, '/history');
}

  void _navigateToReport() {
    try {
      Navigator.pushNamed(context, '/report').catchError((error) {
        _showTemporaryScreen('รายงานหมายเลขหลอกลวง', 'หน้ารายงานหมายเลขหลอกลวงยังไม่พร้อมใช้งาน', Icons.report_problem);
      });
    } catch (e) {
      _showTemporaryScreen('รายงานหมายเลขหลอกลวง', 'หน้ารายงานหมายเลขหลอกลวงยังไม่พร้อมใช้งาน', Icons.report_problem);
    }
  }

  void _navigateToSecurity() {
    try {
      Navigator.pushNamed(context, '/security').catchError((error) {
        _showTemporaryScreen('ตั้งค่าความปลอดภัย', 'หน้าตั้งค่าความปลอดภัยยังไม่พร้อมใช้งาน', Icons.shield);
      });
    } catch (e) {
      _showTemporaryScreen('ตั้งค่าความปลอดภัย', 'หน้าตั้งค่าความปลอดภัยยังไม่พร้อมใช้งาน', Icons.shield);
    }
  }

  void _navigateToNotifications() {
    try {
      Navigator.pushNamed(context, '/notifications').catchError((error) {
        _showTemporaryScreen('การแจ้งเตือน', 'หน้าการแจ้งเตือนยังไม่พร้อมใช้งาน', Icons.notifications);
      });
    } catch (e) {
      _showTemporaryScreen('การแจ้งเตือน', 'หน้าการแจ้งเตือนยังไม่พร้อมใช้งาน', Icons.notifications);
    }
  }

  void _navigateToHelp() {
    try {
      Navigator.pushNamed(context, '/help').catchError((error) {
        _showTemporaryScreen('ความช่วยเหลือ', 'หน้าความช่วยเหลือยังไม่พร้อมใช้งาน', Icons.help_outline);
      });
    } catch (e) {
      _showTemporaryScreen('ความช่วยเหลือ', 'หน้าความช่วยเหลือยังไม่พร้อมใช้งาน', Icons.help_outline);
    }
  }

  void _showTemporaryScreen(String title, String message, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 80,
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('กลับ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      ),
    );
  }

  Widget _buildStatsCard() {
    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) => Transform.scale(
        scale: _statsAnimation.value,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'สถิติการใช้งาน',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildRefreshButton(),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.scanner,
                      title: 'สแกนทั้งหมด',
                      value: '${_userStats?['total_scans'] ?? 0}',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.warning,
                      title: 'พบมิจฉาชีพ',
                      value: '${_userStats?['scam_detected'] ?? 0}',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.report,
                      title: 'รายงานแล้ว',
                      value: '${_userStats?['reports_submitted'] ?? 0}',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.schedule,
                      title: 'สแกนล่าสุด',
                      value: _userStats?['last_scan_date'] != null 
                        ? _formatDate(_userStats!['last_scan_date'])
                        : 'ยังไม่เคย',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: _checkLoginStatusAndFetchProfile,
      icon: const Icon(Icons.refresh, size: 20),
      tooltip: 'รีเฟรชข้อมูล',
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        minimumSize: const Size(32, 32),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) return 'วันนี้';
      if (difference == 1) return 'เมื่อวาน';
      if (difference < 7) return '$difference วันที่แล้ว';
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }

  // Utility methods
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isDestructive ? Icons.warning : Icons.info,
              color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : null,
            ),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool showBadge = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    if (showBadge)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (!_isLoggedIn) {
      return _buildLoginPromptScreen();
    }

    return _buildUserProfileScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'กำลังโหลดข้อมูล...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPromptScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              margin: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ยินดีต้อนรับ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณาเข้าสู่ระบบเพื่อดูข้อมูลโปรไฟล์และสถิติการใช้งาน',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        try {
                          Navigator.pushNamed(context, '/login');
                        } catch (e) {
                          _showSuccessSnackBar('หน้าเข้าสู่ระบบยังไม่พร้อมใช้งาน');
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('เข้าสู่ระบบ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      try {
                        Navigator.pushNamed(context, '/register');
                      } catch (e) {
                        _showSuccessSnackBar('หน้าสมัครสมาชิกยังไม่พร้อมใช้งาน');
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('สมัครสมาชิก'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileScreen() {
    final userName = _userProfile?['full_name'] ?? _auth.currentUser!.email!;
    final userEmail = _auth.currentUser!.email ?? '';
    final isVerified = _auth.currentUser?.emailVerified ?? false;

    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: RefreshIndicator(
          onRefresh: _checkLoginStatusAndFetchProfile,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildProfileCard(userName, userEmail, isVerified),
                          const SizedBox(height: 24),
                          _buildStatsCard(),
                          const SizedBox(height: 24),
                          _buildProfileDetailsCard(),
                          const SizedBox(height: 24),
                          _buildMenuOptionsCard(),
                          const SizedBox(height: 32),
                          _buildVersionInfo(),
                          const SizedBox(height: 24),
                        ],
                      ),
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

  BoxDecoration _buildBackgroundGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).primaryColor.withOpacity(0.1),
          Theme.of(context).colorScheme.surface,
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'โปรไฟล์ผู้ใช้',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(String userName, String userEmail, bool isVerified) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildUserAvatar(userName, isVerified),
          const SizedBox(height: 24),
          Text(
            userName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _buildEmailBadge(userEmail, isVerified),
          if (!isVerified) _buildVerificationButton(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String userName, bool isVerified) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.7),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmailBadge(String userEmail, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_user : Icons.email,
            color: isVerified ? Colors.green : Theme.of(context).primaryColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              userEmail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: () async {
          try {
            await _auth.currentUser?.sendEmailVerification();
            _showSuccessSnackBar('ส่งอีเมลยืนยันแล้ว กรุณาตรวจสอบกล่องจดหมาย');
          } catch (e) {
            _handleError('เกิดข้อผิดพลาดในการส่งอีเมลยืนยัน: $e');
          }
        },
        icon: const Icon(Icons.email, size: 16),
        label: const Text('ยืนยันอีเมล'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange,
        ),
      ),
    );
  }

  Widget _buildProfileDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'ข้อมูลส่วนตัว',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'แก้ไขข้อมูล',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.phone, 'เบอร์โทรศัพท์', _userProfile?['phone'] ?? 'ไม่ได้ระบุ'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today, 'วันเกิด', _formatBirthDate(_userProfile?['dob'])),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on, 'ที่อยู่', _userProfile?['address'] ?? 'ไม่ได้ระบุ'),
        ],
      ),
    );
  }

  String _formatBirthDate(String? dob) {
    if (dob == null || dob.isEmpty) return 'ไม่ได้ระบุ';
    try {
      final date = DateTime.parse(dob);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dob;
    }
  }

  Widget _buildMenuOptionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'การจัดการบัญชี',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMenuButton(
            icon: Icons.lock_outline,
            title: 'เปลี่ยนรหัสผ่าน',
            subtitle: 'เพิ่มความปลอดภัยให้บัญชี',
            onTap: _showChangePasswordDialog,
          ),
          _buildMenuButton(
            icon: Icons.history,
            title: 'ประวัติการใช้งาน',
            subtitle: 'ดูรายการสแกนและรายงานที่ผ่านมา',
            onTap: _navigateToHistory,
          ),
          _buildMenuButton(
            icon: Icons.report_problem,
            title: 'รายงานหมายเลขหลอกลวง',
            subtitle: 'แจ้งเบอร์โทรหรือข้อความต้องสงสัย',
            onTap: _navigateToReport,
            iconColor: Colors.orange,
          ),
          _buildMenuButton(
            icon: Icons.shield,
            title: 'ตั้งค่าความปลอดภัย',
            subtitle: 'การยืนยันตัวตน 2 ขั้นตอน',
            onTap: _navigateToSecurity,
            iconColor: Colors.green,
          ),
          _buildMenuButton(
            icon: Icons.notifications,
            title: 'การแจ้งเตือน',
            subtitle: 'จัดการการแจ้งเตือนและการอัปเดต',
            onTap: _navigateToNotifications,
            iconColor: Colors.blue,
          ),
          _buildMenuButton(
            icon: Icons.help_outline,
            title: 'ความช่วยเหลือ',
            subtitle: 'คำถามที่พบบ่อยและการติดต่อ',
            onTap: _navigateToHelp,
            iconColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Anti-Scam AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'เวอร์ชัน 1.0.0 | ปกป้องคุณจากการหลอกลวง',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 Anti-Scam Team. สงวนลิขสิทธิ์.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}