import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MealService {
  // 실제 GitHub Raw URL로 업데이트합니다.
  static const String _url = 'https://raw.githubusercontent.com/wikiwiki1006/ajouapp/main/assets/data/meals.json';

  Future<Map<String, dynamic>?> getWeeklyMeals() async {
    try {
      debugPrint('식단 데이터를 URL에서 가져오는 중: $_url');
      final response = await http.get(Uri.parse(_url));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint('식단 데이터 가져오기 성공');
        return Map<String, dynamic>.from(decodedData);
      } else {
        debugPrint('식단 데이터 로딩 실패 (HTTP ${response.statusCode})');
        return null;
      }
    } catch (e) {
      debugPrint('식단 서비스 예외 발생: $e');
      return null;
    }
  }
}
