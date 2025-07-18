import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:anti_scam_ai/services/gemini_api.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  
  // Cache สำหรับเก็บผลลัพธ์การวิเคราะห์
  static final Map<String, Map<String, dynamic>> _analysisCache = {};
  
  bool _loading = false;
  bool _hasResult = false;
  bool _isScam = false;
  String _resultText = '';
  String _reason = '';
  String? _currentRequestId; // ป้องกันการกดซ้ำ

  @override
  bool get wantKeepAlive => true; // คง state ไว้เมื่อสลับหน้า

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {}); // อัปเดตปุ่มตรวจสอบ enable/disable ตามข้อความ
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // สร้าง hash key สำหรับ cache
  String _generateCacheKey(String input) {
    final bytes = utf8.encode(input.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ตรวจสอบว่ามีใน cache แล้วหรือไม่
  bool _isCached(String input) {
    final key = _generateCacheKey(input);
    return _analysisCache.containsKey(key);
  }

  // ดึงผลลัพธ์จาก cache
  Map<String, dynamic>? _getCachedResult(String input) {
    final key = _generateCacheKey(input);
    return _analysisCache[key];
  }

  // บันทึกผลลัพธ์ลง cache
  void _saveToCacheIfValid(String input, Map<String, dynamic> result) {
    if (input.trim().isNotEmpty && result.isNotEmpty) {
      final key = _generateCacheKey(input);
      _analysisCache[key] = result;
      
      // จำกัดขนาด cache ไม่เกิน 50 รายการ
      if (_analysisCache.length > 50) {
        final firstKey = _analysisCache.keys.first;
        _analysisCache.remove(firstKey);
      }
    }
  }

  Future<void> _analyzeText() async {
    final input = _textController.text.trim();
    if (input.isEmpty || _loading) return;

    // สร้าง request ID เพื่อป้องกันการกดซ้ำ
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRequestId = requestId;

    setState(() {
      _loading = true;
      _hasResult = false;
    });

    try {
      Map<String, dynamic> analysis;

      // ตรวจสอบ cache ก่อน
      if (_isCached(input)) {
        print('📋 ใช้ผลลัพธ์จาก cache');
        analysis = _getCachedResult(input)!;
        
        // จำลอง delay เล็กน้อยเพื่อ UX ที่ดี
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        print('🔍 เรียก Gemini API');
        analysis = await GeminiApi.analyzeMessageWithReason(input);
        
        // บันทึกลง cache
        _saveToCacheIfValid(input, analysis);
      }

      // ตรวจสอบว่า request นี้ยังเป็น request ล่าสุดหรือไม่
      if (_currentRequestId != requestId) {
        print('🚫 Request ถูกยกเลิกเพราะมี request ใหม่');
        return;
      }

      setState(() {
        _isScam = analysis['isScam'] as bool? ?? false;
        _reason = analysis['reason'] as String? ?? '';
        _resultText = _isScam ? 'ข้อความนี้มีความเสี่ยงเป็นสแปมหรือหลอกลวง' : 'ข้อความนี้ปลอดภัย';
        _hasResult = true;
      });

    } catch (e) {
      // ตรวจสอบว่า request นี้ยังเป็น request ล่าสุดหรือไม่
      if (_currentRequestId != requestId) return;

      setState(() {
        _resultText = 'เกิดข้อผิดพลาดในการวิเคราะห์: $e';
        _isScam = false;
        _reason = '';
        _hasResult = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถวิเคราะห์ข้อความได้ กรุณาลองใหม่', 
                         style: GoogleFonts.kanit()),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (_currentRequestId == requestId && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _clearText() {
    _textController.clear();
    setState(() {
      _hasResult = false;
      _resultText = '';
      _reason = '';
      _isScam = false;
    });
  }

  // แสดงจำนวน cache ที่มี (สำหรับ debug)
  void _showCacheInfo() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💾 มีข้อมูล cache: ${_analysisCache.length} รายการ', 
                       style: GoogleFonts.kanit()),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // สำคัญสำหรับ AutomaticKeepAliveClientMixin
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // กำหนดสีพื้นหลัง Card ตามธีมและสถานะ Scam
    Color cardBackgroundColor() {
      if (_isScam) {
        return isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100;
      } else {
        return isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100;
      }
    }

    // กำหนดสีข้อความผลลัพธ์ตามธีมและสถานะ Scam
    Color resultTextColor() {
      if (_isScam) {
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      } else {
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      }
    }

    // ตรวจสอบว่าข้อความปัจจุบันมีใน cache หรือไม่
    final currentInput = _textController.text.trim();
    final isCurrentCached = currentInput.isNotEmpty && _isCached(currentInput);

    return Scaffold(
      appBar: AppBar(
        title: Text('ตรวจสอบข้อความ', style: GoogleFonts.kanit()),
        actions: [
          // ปุ่ม debug สำหรับดู cache info
          if (_analysisCache.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_analysisCache.length}'),
                child: const Icon(Icons.storage),
              ),
              onPressed: _showCacheInfo,
              tooltip: 'ดูข้อมูล Cache',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              TextField(
                controller: _textController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'วางข้อความที่ต้องการตรวจสอบ',
                  labelStyle: GoogleFonts.kanit(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // แสดง icon cache หากข้อความนี้มีใน cache
                            if (isCurrentCached)
                              Icon(
                                Icons.cached,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            IconButton(
                              icon: Icon(Icons.clear, color: theme.colorScheme.primary),
                              onPressed: _clearText,
                            ),
                          ],
                        ),
                  helperText: isCurrentCached ? '💾 ข้อความนี้เคยวิเคราะห์แล้ว (ใช้ cache)' : null,
                  helperStyle: GoogleFonts.kanit(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textInputAction: TextInputAction.done,
                cursorColor: theme.colorScheme.primary,
                onSubmitted: (_) => _analyzeText(), // กด Enter ก็ได้
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, 
                            strokeWidth: 2
                          ),
                        )
                      : Icon(isCurrentCached ? Icons.cached : Icons.search),
                  label: Text(
                    _loading 
                        ? 'กำลังวิเคราะห์...' 
                        : isCurrentCached 
                            ? 'ตรวจสอบข้อความ (เร็ว)'
                            : 'ตรวจสอบข้อความ',
                    style: GoogleFonts.kanit(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_loading || _textController.text.trim().isEmpty) 
                      ? null 
                      : _analyzeText,
                ),
              ),
              const SizedBox(height: 24),
              if (_hasResult)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  color: cardBackgroundColor(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isScam ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: resultTextColor(),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _resultText,
                                style: GoogleFonts.kanit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: resultTextColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_reason.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'เหตุผล:',
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _reason,
                            style: GoogleFonts.kanit(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              
              // แสดงสถิติ cache (สำหรับ debug)
              if (_analysisCache.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '💾 ประหยัด API calls: ${_analysisCache.length} ครั้ง',
                    style: GoogleFonts.kanit(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
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