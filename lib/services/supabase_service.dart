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

  // 장소 이름으로 검색 (DB 기반)
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

  // 택시 방 목록 가져오기 (실시간 스트림, 현재 시간 이후의 방만 표시)
  Stream<List<TaxiRoom>> getTaxiRooms() {
    return _client
        .from('taxi_rooms')
        .stream(primaryKey: ['id'])
        .order('departure_time', ascending: true)
        .map((data) => data
            .map((json) => TaxiRoom.fromMap(json))
            .where((room) => room.departureTime.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) // 1시간 이내 지난 방까지만 표시
            .toList());
  }

  // 택시 방 삭제
  Future<void> deleteTaxiRoom(String roomId) async {
    try {
      // .select()를 붙이면 삭제된 데이터를 반환합니다. 
      // 만약 반환값이 비어있다면 권한이 없어서 삭제가 안 된 것입니다.
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

  // 택시 방 참가
  Future<bool> joinTaxiRoom(String roomId, String userId) async {
    final response = await _client
        .from('taxi_rooms')
        .select('participants, max_people')
        .eq('id', roomId)
        .single();
    
    List<String> participants = List<String>.from(response['participants'] ?? []);
    int maxPeople = response['max_people'] ?? 4;

    // 이미 참여 중이면 바로 성공 처리
    if (participants.contains(userId)) return true;

    // 인원 제한 체크
    if (participants.length >= maxPeople) {
      return false; // 정원 초과
    }

    // 인원 추가
    participants.add(userId);
    await _client
        .from('taxi_rooms')
        .update({'participants': participants})
        .eq('id', roomId);
    
    return true;
  }
}
