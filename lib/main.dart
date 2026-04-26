import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://thbutqwclmslaglmwymw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoYnV0cXdjbG1zbGFnbG13eW13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMzg3NTUsImV4cCI6MjA5MjcxNDc1NX0.Vy76nS_1UvNMp17LxPmeGSAMv-rMe2M_Dn8BZs1IPok',
    debug: kDebugMode,
  );

  // 모바일 환경에서만 네이버 지도 초기화
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    debugPrint("네이버 지도 초기화 시작 (Native에서 인증 처리됨)");
    await NaverMapSdk.instance.initialize(
      onAuthFailed: (ex) => debugPrint("네이버 지도 인증 실패 상세: $ex"),
    );
  }

  runApp(const UniversityApp());
}

class UniversityApp extends StatelessWidget {
  const UniversityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아주MATE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B64DA),
          primary: const Color(0xFF1B64DA),
          secondary: const Color(0xFFFF8C00),
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withAlpha(20),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F4F6),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF191F28),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF4E5968)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B64DA),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
