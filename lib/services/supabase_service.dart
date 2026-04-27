import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/taxi_room.dart';
import '../models/message.dart';

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

  // 장소 이름으로 검색 (DB 기반) - 이전에 추가한 메서드 (필요시 유지)
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      final response = await _client
          .from('locations')
          .select()
          .ilike('name', '%$query%'); // 대소문자 구분 없이 포함된 단어 검색
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

  // 만료된 방 자동 삭제 (출발 시간이 1시간 이상 지난 방만 삭제하여 여유 공간 확보)
  Future<void> cleanupOldRooms() async {
    try {
      // 현재 시간보다 1시간 전보다 더 과거인 방만 삭제 (시간차/오차 고려)
      final expiryTime = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
      await _client
          .from('taxi_rooms')
          .delete()
          .lt('departure_time', expiryTime);
    } catch (e) {
      print("만료된 방 정리 오류: $e");
    }
  }

  // 순차적 채팅 링크 가져오기 (현재 사용 중인 링크 제외)
  Future<String?> getSequentialChatLink() async {
    try {
      // 0. 먼저 만료된 방들을 정리하여 링크를 풀로 복구
      await cleanupOldRooms();

      // 1. 현재 생성되어 있는 모든 방에서 사용 중인 링크 목록 가져오기 (시간 상관 없이)
      final activeRoomsResponse = await _client
          .from('taxi_rooms')
          .select('chat_url');
      
      // null 값을 안전하게 처리하여 문자열 리스트로 변환
      final List<String> usedUrls = (activeRoomsResponse as List)
          .map((item) => item['chat_url']?.toString())
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

      // 2. 사용 중이지 않은 링크 중 사용 횟수가 적고 오래된 것 가져오기
      var query = _client.from('chat_pool').select();
      
      if (usedUrls.isNotEmpty) {
        // 중복 방지를 위해 현재 taxi_rooms 테이블에 존재하는 모든 URL 제외
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

        // 3. 사용 횟수 증가 및 마지막 사용 시간 업데이트
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

  // 특정 방의 채팅 메시지 가져오기 (실시간 스트림)
  Stream<List<Message>> getMessages(String roomId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => Message.fromMap(json)).toList());
  }

  // 메시지 전송
  Future<void> sendMessage(String roomId, String senderName, String content) async {
    final userId = currentUserId;
    if (userId == null) return;

    final message = Message(
      id: '', // DB에서 생성
      roomId: roomId,
      senderId: userId,
      senderName: senderName,
      content: content,
      createdAt: DateTime.now(),
    );

    await _client.from('messages').insert(message.toMap());
  }

  // 택시 방 시간 수정
  Future<void> updateRoomTime(String roomId, DateTime newTime) async {
    await _client
        .from('taxi_rooms')
        .update({'departure_time': newTime.toIso8601String()})
        .eq('id', roomId);
  }

  // 특정 방 상세 정보 가져오기 (알림 감지용)
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

    if (participants.length >= maxPeople) {
      return false;
    }

    participants.add(userId);
    await _client
        .from('taxi_rooms')
        .update({'participants': participants})
        .eq('id', roomId);
    
    return true;
  }
}
