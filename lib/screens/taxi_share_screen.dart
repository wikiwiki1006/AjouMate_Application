import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/taxi_room.dart';
import 'create_room_screen.dart';
import 'chat_screen.dart';

class TaxiShareScreen extends StatefulWidget {
  const TaxiShareScreen({super.key});

  @override
  State<TaxiShareScreen> createState() => _TaxiShareScreenState();
}

class _TaxiShareScreenState extends State<TaxiShareScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _supabaseService.signInAnonymously();
  }

  void _enterRoom(TaxiRoom room) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    final bool success = await _supabaseService.joinTaxiRoom(room.id, userId);
    if (mounted) {
      if (success) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(room: room, userName: '사용자_${userId.substring(0, 4)}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정원이 가득 차서 입장할 수 없습니다.')));
      }
    }
  }

  void _deleteRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('방 삭제'),
        content: const Text('정말로 이 방을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabaseService.deleteTaxiRoom(roomId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('방이 삭제되었습니다.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    const Color primaryOrange = Color(0xFFFF8C00);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text('택시 합승', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(50),
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
      body: StreamBuilder<List<TaxiRoom>>(
        stream: _supabaseService.getTaxiRooms(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('에러: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rooms = snapshot.data ?? [];
          if (rooms.isEmpty) return const Center(child: Text('현재 개설된 방이 없습니다.', style: TextStyle(color: Color(0xFF8B95A1))));

          return ListView.builder(
            itemCount: rooms.length,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final timeStr = DateFormat('HH:mm').format(room.departureTime);
              final dateStr = DateFormat('MM월 dd일').format(room.departureTime);
              final isFull = room.participants.length >= room.maxPeople;
              final isParticipant = room.participants.contains(_supabaseService.currentUserId);
              final isCreator = room.creatorId == _supabaseService.currentUserId;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: primaryBlue.withAlpha(60), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: (isFull && !isParticipant) ? null : () => _enterRoom(room),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryBlue.withAlpha(30),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
                          border: Border(bottom: BorderSide(color: primaryBlue.withAlpha(60), width: 1)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
                                  child: Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                if (isCreator && room.participants.length <= 1)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteRoom(room.id),
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFF04452), size: 22),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildLocationRow(Icons.radio_button_checked, primaryBlue, room.startLocationName, '출발'),
                            const SizedBox(height: 12),
                            _buildLocationRow(Icons.location_on, primaryOrange, room.endLocationName, '도착'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildInfoChip(Icons.schedule, timeStr, const Color(0xFF4E5968)),
                                const SizedBox(width: 8),
                                _buildInfoChip(Icons.group, '${room.participants.length}/${room.maxPeople}명', isFull ? const Color(0xFFF04452) : const Color(0xFF4E5968)),
                              ],
                            ),
                            Text(
                              (isFull && !isParticipant) ? '모집 완료' : (isParticipant ? '참여 중' : '입장하기'),
                              style: TextStyle(color: (isFull && !isParticipant) ? const Color(0xFF8B95A1) : primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomScreen())),
        backgroundColor: primaryBlue,
        label: const Text('방 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180), fontWeight: FontWeight.bold)),
              Text(location, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF191F28))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30), 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
