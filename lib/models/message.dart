class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      id: data['id'].toString(),
      roomId: data['room_id'].toString(),
      senderId: data['sender_id'] ?? '',
      senderName: data['sender_name'] ?? '',
      content: data['content'] ?? '',
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
    };
  }
}
