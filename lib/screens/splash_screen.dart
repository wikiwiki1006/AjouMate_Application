import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // 앱 시작 시 2초 대기
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('has_agreed_to_terms') ?? false;

    if (hasAgreed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 학교 로고 이미지
            Image.network(
              'https://www.ajou.ac.kr/_res/ajou/kr/img/intro/img-system02.png',
              width: 180,
              errorBuilder: (context, error, stackTrace) {
                // 이미지 로드 실패 시 대체 아이콘
                return const Icon(Icons.school, size: 100, color: Color(0xFF0054A6));
              },
            ),
            const SizedBox(height: 24),
            // 앱 이름 (아주MATE)
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                children: [
                  TextSpan(
                    text: '아주',
                    style: TextStyle(color: Color(0xFF0054A6)), // 아주대 심볼 컬러
                  ),
                  TextSpan(
                    text: 'MATE',
                    style: TextStyle(color: Color(0xFFF7941D)), // 포인트 컬러
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
