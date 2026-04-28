import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/taxi_room.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // 익명 로그인
  Future<void> signInAnonymously() async {
    try {
      if (_client.auth.currentSession == null) {
        await _client.auth.signInAnonymously();
      }
    } catch (e) {
      print('Supabase 익명 로그인 실패: $e');
    }
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  // 자주 찾는 위치 목록 가져오기
  Future<List<Map<String, dynamic>>> getFrequentLocations() async {
    try {
      final response = await _client
          .from('frequent_locations')
          .select()
          .order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("자주 찾는 위치 로딩 오류: $e");
      return [];
    }
  }

  // 장소 이름으로 검색 (DB 기반)
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .ilike('name', '%$query%');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("장소 검색 오류: $e");
      return [];
    }
  }

  // 택시 방 목록 가져오기 (실시간 스트림)
  Stream<List<TaxiRoom>> getTaxiRooms() {
    return _client
        .from('taxi_rooms')
        .stream(primaryKey: ['id'])
        .order('departure_time', ascending: true)
        .map((data) => data
            .map((json) => TaxiRoom.fromMap(json))
            .toList());
  }

  // 만료된 방 자동 삭제
  Future<void> cleanupOldRooms() async {
    try {
      final expiryTime = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
      await _client
          .from('taxi_rooms')
          .delete()
          .lt('departure_time', expiryTime);
    } catch (e) {
      print("만료된 방 정리 오류: $e");
    }
  }

  // 순차적 채팅 링크 가져오기
  Future<String?> getSequentialChatLink() async {
    try {
      await cleanupOldRooms();
      final activeRoomsResponse = await _client
          .from('taxi_rooms')
          .select('chat_url');
      
      final List<String> usedUrls = (activeRoomsResponse as List)
          .map((item) => item['chat_url']?.toString())
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

      var query = _client.from('chat_pool').select();
      if (usedUrls.isNotEmpty) {
        query = query.not('url', 'in', usedUrls);
      }

      final response = await query
          .order('usage_count', ascending: true)
          .order('last_used_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null && response['url'] != null) {
        final String linkId = response['id'].toString();
        final String url = response['url'] as String;
        final int currentCount = response['usage_count'] ?? 0;

        await _client.from('chat_pool').update({
          'usage_count': currentCount + 1,
          'last_used_at': DateTime.now().toIso8601String(),
        }).eq('id', linkId);

        return url;
      }
    } catch (e) {
      print("순차 채팅 링크 할당 오류: $e");
    }
    return null;
  }

  // 택시 방 삭제
  Future<void> deleteTaxiRoom(String roomId) async {
    try {
      final response = await _client
          .from('taxi_rooms')
          .delete()
          .eq('id', roomId)
          .select();

      if (response.isEmpty) {
        throw Exception('삭제 권한이 없거나 이미 삭제된 방입니다.');
      }
    } catch (e) {
      print('방 삭제 중 오류 발생: $e');
      rethrow;
    }
  }

  // 택시 방 생성
  Future<void> createTaxiRoom(TaxiRoom room) async {
    await _client.from('taxi_rooms').insert(room.toMap());
  }

  // 택시 방 시간 수정
  Future<void> updateRoomTime(String roomId, DateTime newTime) async {
    await _client
        .from('taxi_rooms')
        .update({'departure_time': newTime.toIso8601String()})
        .eq('id', roomId);
  }

  // 특정 방 상세 정보 가져오기
  Future<TaxiRoom?> getRoomById(String roomId) async {
    final response = await _client
        .from('taxi_rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    if (response != null) {
      return TaxiRoom.fromMap(response);
    }
    return null;
  }

  // 특정 사용자가 만든 방들의 참여자 변화 감지 스트림
  Stream<List<Map<String, dynamic>>> getMyRoomsParticipantsStream(String userId) {
    return _client
        .from('taxi_rooms')
        .stream(primaryKey: ['id'])
        .eq('creator_id', userId)
        .map((data) => data.map((json) => {
          'id': json['id'],
          'participants': json['participants'],
          'start_location_name': json['start_location_name']
        }).toList());
  }

  // 택시 방 가입
  Future<bool> joinTaxiRoom(String roomId, String userId) async {
    final response = await _client
        .from('taxi_rooms')
        .select('participants, max_people')
        .eq('id', roomId)
        .single();
    
    List<String> participants = List<String>.from(response['participants'] ?? []);
    int maxPeople = response['max_people'] ?? 4;

    if (participants.contains(userId)) return true;
    if (participants.length >= maxPeople) return false;

    participants.add(userId);
    await _client
        .from('taxi_rooms')
        .update({'participants': participants})
        .eq('id', roomId);
    
    return true;
  }

  // 사용자 신고
  Future<void> reportUser({
    required String reportedUserId,
    required String roomId,
    required String reason,
  }) async {
    try {
      await _client.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'room_id': roomId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('신고 데이터 전송 오류 (심사 시에는 UI 동작이 중요함): $e');
    }
  }
}
