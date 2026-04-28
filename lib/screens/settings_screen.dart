import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAccountData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 삭제 및 탈퇴'),
        content: const Text('정말로 탈퇴하시겠습니까?\n이 기기에서 생성한 모든 데이터와 차단 목록이 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. 로컬 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Supabase 세션 로그아웃 (익명 세션 종료)
      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터가 성공적으로 삭제되었습니다.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showPrivacyPolicy(BuildContext context) async {
    const url = 'https://wikiwiki1006.github.io/ajou.universityapp/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 웹사이트 연결 실패 시 기존 다이얼로그 방식 유지 (Fallback)
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('개인정보 처리방침'),
            content: const SingleChildScrollView(
              child: Text(
                '본 앱은 아주대학교 학생들의 편의를 위해 제공되는 서비스입니다.\n\n'
                '1. 수집하는 정보: 익명 사용자 식별자(UUID), 기기 설정값.\n'
                '2. 이용 목적: 택시 합승 방 생성 시 사용자 식별, 부적절한 사용자 차단.\n'
                '3. 보유 기간: 서비스 이용 기간 동안 보유하며, 사용자가 데이터 삭제를 요청할 경우 즉시 파기합니다.\n'
                '4. 동의 거부: 정보 수집에 동의하지 않을 경우 일부 서비스(택시 합승 등) 이용이 제한될 수 있습니다.',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: const Color(0xFF1B64DA),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('앱 정보'),
          _buildListTile(
            context,
            '개인정보 처리방침',
            Icons.privacy_tip_outlined,
            onTap: () => _showPrivacyPolicy(context),
          ),
          _buildListTile(
            context,
            '이용 약관 (UGC 규정)',
            Icons.description_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('이용 약관'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '택시 합승 서비스 이용 시 다음 규정을 준수해야 합니다.\n\n'
                      '1. 부적절한 콘텐츠(욕설, 비하, 광고 등) 게시 금지.\n'
                      '2. 허위 정보 게시 금지.\n'
                      '3. 타인에게 불쾌감을 주는 행위 금지.\n\n'
                      '위반 시 서비스 이용이 제한될 수 있으며, 게시물은 신고를 통해 즉시 삭제될 수 있습니다.',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('계정 관리'),
          _buildListTile(
            context,
            '데이터 삭제 및 서비스 탈퇴',
            Icons.delete_forever_outlined,
            textColor: Colors.red,
            onTap: () => _deleteAccountData(context),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'v1.0.0 | 아주MATE',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B64DA),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon,
      {VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
