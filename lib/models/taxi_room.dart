class TaxiRoom {
  final String id;
  final String creatorId;
  final String creatorName;
  final String startLocationName;
  final double startLat;
  final double startLng;
  final String endLocationName;
  final double endLat;
  final double endLng;
  final DateTime departureTime;
  final int maxPeople;
  final List<String> participants;
  final DateTime createdAt;
  final String? chatUrl; // 카카오톡 오픈채팅 링크 추가

  TaxiRoom({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.startLocationName,
    required this.startLat,
    required this.startLng,
    required this.endLocationName,
    required this.endLat,
    required this.endLng,
    required this.departureTime,
    required this.maxPeople,
    required this.participants,
    required this.createdAt,
    this.chatUrl,
  });

  factory TaxiRoom.fromMap(Map<String, dynamic> data) {
    return TaxiRoom(
      id: data['id'].toString(),
      creatorId: data['creator_id'] ?? '',
      creatorName: data['creator_name'] ?? '',
      startLocationName: data['start_location_name'] ?? '',
      startLat: (data['start_lat'] ?? 0).toDouble(),
      startLng: (data['start_lng'] ?? 0).toDouble(),
      endLocationName: data['end_location_name'] ?? '',
      endLat: (data['end_lat'] ?? 0).toDouble(),
      endLng: (data['end_lng'] ?? 0).toDouble(),
      departureTime: DateTime.parse(data['departure_time']),
      maxPeople: data['max_people'] ?? 4,
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: DateTime.parse(data['created_at']),
      chatUrl: data['chat_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'creator_name': creatorName,
      'start_location_name': startLocationName,
      'start_lat': startLat,
      'start_lng': startLng,
      'end_location_name': endLocationName,
      'end_lat': endLat,
      'end_lng': endLng,
      'departure_time': departureTime.toIso8601String(),
      'max_people': maxPeople,
      'participants': participants,
      'chat_url': chatUrl,
    };
  }
}
