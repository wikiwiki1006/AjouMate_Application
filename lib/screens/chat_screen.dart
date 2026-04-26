import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/taxi_room.dart';
import '../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final TaxiRoom room;
  final String userName;

  const ChatScreen({super.key, required this.room, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = SupabaseService();
  final _controller = TextEditingController();

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    await _service.sendMessage(widget.room.id, widget.userName, _controller.text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.room.startLocationName} -> ${widget.room.endLocationName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _service.getMessages(widget.room.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.reversed.toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true, // 최신 메시지가 아래에 오도록 설정
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _service.currentUserId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(msg.content),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: '메시지를 입력하세요...'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
