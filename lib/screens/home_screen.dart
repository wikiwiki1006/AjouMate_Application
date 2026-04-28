import 'package:flutter/material.dart';
import 'meal_screen.dart';
import 'shuttle_screen.dart';
import 'notice_screen.dart';
import 'taxi_share_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: '아주', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'MATE', style: TextStyle(color: Color(0xFFFF8C00))),
            ],
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 4,
        shadowColor: Colors.black.withAlpha(80),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [primaryBlue, Color(0xFF1552B1)],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withAlpha(50), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: primaryBlue, size: 18),
                  SizedBox(width: 10),
                  Text(
                    '오늘도 즐거운 학교 생활 되세요!',
                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.85,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildServiceCard(context, '오늘의 식단', '오늘 뭐 나올까?', Icons.restaurant, const Color(0xFF24AE5D), const MealScreen(), primaryBlue),
                  _buildServiceCard(context, '셔틀 시간표', '버스 언제 올까?', Icons.bus_alert, const Color(0xFF4E5968), const ShuttleScreen(), primaryBlue),
                  _buildServiceCard(context, '학교 공지', '새로운 소식', Icons.campaign, const Color(0xFFFF8C00), const NoticeScreen(), primaryBlue),
                  _buildServiceCard(context, '택시 합승', '요금을 나눠요', Icons.local_taxi, primaryBlue, const TaxiShareScreen(), primaryBlue),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'v0.0.0 | wikiwiki041006@gmail.com',
                style: TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget screen, Color primaryBlue) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primaryBlue.withAlpha(80), width: 3.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(40), width: 1),
                  ),
                  child: Icon(icon, color: color, size: 36),
                ),
                const Spacer(),
                Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191F28)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7684), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
