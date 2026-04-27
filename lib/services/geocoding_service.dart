import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_naver_map/flutter_naver_map.dart';

class GeocodingService {
  static const String _clientId = 'fgdysmkced';
  static const String _clientSecret = 'I6qtdgMc6FrtJXt8SB54T65THSvVXPw2JyfFUahl'; 

  // 1. 역지오코딩 (좌표 -> 주소)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final url = Uri.https('maps.apigw.ntruss.com', '/map-reversegeocode/v2/gc', {
      'coords': '$lng,$lat',
      'output': 'json',
      'orders': 'addr,roadaddr',
    });

    try {
      final response = await http.get(url, headers: {
        'x-ncp-apigw-api-key-id': _clientId,
        'x-ncp-apigw-api-key': _clientSecret,
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] == null || (data['results'] as List).isEmpty) return null;

        final results = data['results'] as List;
        var targetResult = results.firstWhere(
          (r) => r['name'] == 'roadaddr' || r['name'] == 'addr', 
          orElse: () => results.first
        );

        final region = targetResult['region'];
        final a1 = region['area1']?['name'] ?? '';
        final a2 = region['area2']?['name'] ?? '';
        final a3 = region['area3']?['name'] ?? '';
        final a4 = region['area4']?['name'] ?? '';
        
        String address = "$a1 $a2 $a3 $a4".trim();
        final land = targetResult['land'];
        if (land != null) {
          final n1 = land['number1'] ?? '';
          final n2 = land['number2'] ?? '';
          if (n1.isNotEmpty) address += " $n1${n2.isNotEmpty ? '-$n2' : ''}";
        }
        return address.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    } catch (e) {
      print("Reverse Geocoding Error: $e");
    }
    return null;
  }

  // 2. 지오코딩 (통합 검색용)
  // NCP Maps 서비스의 유일한 검색 수단입니다.
  static Future<List<Map<String, dynamic>>> geocode(String query) async {
    final url = Uri.https('maps.apigw.ntruss.com', '/map-geocode/v2/geocode', {
      'query': query,
    });

    try {
      final response = await http.get(url, headers: {
        'x-ncp-apigw-api-key-id': _clientId,
        'x-ncp-apigw-api-key': _clientSecret,
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['addresses'] != null) {
          return (data['addresses'] as List).map((addr) {
            // 지오코딩 결과에서 '주소'와 '랜드마크명'을 적절히 추출
            return {
              'name': addr['roadAddress'] ?? addr['jibunAddress'],
              'roadAddress': addr['roadAddress'],
              'jibunAddress': addr['jibunAddress'],
              'latLng': NLatLng(double.parse(addr['y']), double.parse(addr['x'])),
            };
          }).toList();
        }
      }
    } catch (e) {
      print("Geocoding Error: $e");
    }
    return [];
  }

  // searchPlaces 메서드는 NCP Maps 서비스 사양에 맞춰 geocode로 대체
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    return await geocode(query);
  }
}
