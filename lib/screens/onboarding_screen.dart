import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _agreedToPrivacy = false;
  bool _agreedToTerms = false;

  Future<void> _completeOnboarding() async {
    if (_agreedToPrivacy && _agreedToTerms) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_agreed_to_terms', true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '반갑습니다!\n아주MATE 시작하기',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191F28),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '편리한 학교 생활을 위해\n서비스 이용 약관에 동의해주세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4E5968),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildAgreementTile(
                      '개인정보 처리방침 동의 (필수)',
                      _agreedToPrivacy,
                      (val) => setState(() => _agreedToPrivacy = val!),
                      onView: () {
                        // SettingsScreen에 구현된 다이얼로그 재활용 로직은 복잡하므로 
                        // 여기서는 간단한 텍스트 팝업을 띄웁니다.
                        _showSimpleDialog('개인정보 처리방침', '수집 항목: 익명 식별자, 위치 정보\n이용 목적: 서비스 제공 및 사용자 식별\n보유 기간: 서비스 탈퇴 시까지');
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildAgreementTile(
                      '이용 약관 및 UGC 규정 동의 (필수)',
                      _agreedToTerms,
                      (val) => setState(() => _agreedToTerms = val!),
                      onView: () {
                        _showSimpleDialog('이용 약관', '1. 부적절한 콘텐츠 게시 금지\n2. 타인 비방 및 허위 정보 유포 금지\n3. 위반 시 이용 제한 가능');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (_agreedToPrivacy && _agreedToTerms) ? _completeOnboarding : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '동의하고 시작하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementTile(String title, bool value, ValueChanged<bool?> onChanged, {required VoidCallback onView}) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1B64DA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, color: Color(0xFF333D4B), fontWeight: FontWeight.w500),
            ),
          ),
        ),
        TextButton(
          onPressed: onView,
          child: const Text('보기', style: TextStyle(color: Color(0xFF8B95A1), fontSize: 13, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }
}
