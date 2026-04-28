import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/supabase_service.dart';
import '../models/taxi_room.dart';
import 'create_room_screen.dart';

class TaxiShareScreen extends StatefulWidget {
  const TaxiShareScreen({super.key});

  @override
  State<TaxiShareScreen> createState() => _TaxiShareScreenState();
}

class _TaxiShareScreenState extends State<TaxiShareScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  DateTime? _filterDate;
  StreamSubscription? _participantsSubscription;
  Map<String, int> _lastParticipantCounts = {};
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadBlockedUsers();
    _supabaseService.signInAnonymously().then((_) => _setupParticipantListener());
  }

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blockedUserIds = prefs.getStringList('blocked_users') ?? [];
    });
  }

  Future<void> _blockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _blockedUserIds.add(userId);
    await prefs.setStringList('blocked_users', _blockedUserIds);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자가 차단되었습니다. 해당 사용자의 방은 더 이상 보이지 않습니다.')),
      );
    }
  }

  void _showReportDialog(TaxiRoom room) {
    final reasons = ['부적절한 방 제목/내용', '허위 정보 게시', '낚시/피싱 의심', '기타'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('신고하기', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () async {
              Navigator.pop(context);
              await _supabaseService.reportUser(
                reportedUserId: room.creatorId,
                roomId: room.id,
                reason: reason,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('신고가 접수되었습니다. 관리자 검토 후 조치하겠습니다.')),
                );
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showBlockConfirmDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('사용자 차단'),
        content: const Text('정말로 이 사용자를 차단하시겠습니까?\n차단하면 이 사용자가 만든 방이 목록에서 사라집니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(userId);
            },
            child: const Text('차단', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _participantsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const androidSetup = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSetup = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(android: androidSetup, iOS: iosSetup),
    );
  }

  void _setupParticipantListener() {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    _participantsSubscription = _supabaseService.getMyRoomsParticipantsStream(userId).listen((rooms) {
      for (var room in rooms) {
        final roomId = room['id'];
        final participants = List<String>.from(room['participants'] ?? []);
        final count = participants.length;
        final roomName = room['start_location_name'] ?? '방';

        if (_lastParticipantCounts.containsKey(roomId)) {
          if (count > _lastParticipantCounts[roomId]!) {
            _showNotification('새로운 참여자!', '[$roomName] 방에 새로운 메이트가 들어왔습니다.');
          }
        }
        _lastParticipantCounts[roomId] = count;
      }
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'taxi_channel', 'Taxi Notifications', importance: Importance.max, priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  void _selectFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    setState(() => _filterDate = picked);
  }

  void _editRoomTime(TaxiRoom room) async {
    DateTime selectedDate = room.departureTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(room.departureTime);

    final newDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7)));
    if (newDate == null) return;

    if (!mounted) return;
    
    TimeOfDay? newTime;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA), border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(child: const Text('취소', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
                  CupertinoButton(child: const Text('확인', style: TextStyle(color: Color(0xFF1B64DA), fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(newDate.year, newDate.month, newDate.day, selectedTime.hour, selectedTime.minute),
                onDateTimeChanged: (DateTime newDateTime) { newTime = TimeOfDay.fromDateTime(newDateTime); },
              ),
            ),
          ],
        ),
      ),
    );

    newTime ??= selectedTime;
    final updatedDeparture = DateTime(newDate.year, newDate.month, newDate.day, newTime!.hour, newTime!.minute);
    if (updatedDeparture.isBefore(DateTime.now())) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('과거 시간으로 변경할 수 없습니다.')));
      return;
    }

    try {
      await _supabaseService.updateRoomTime(room.id, updatedDeparture);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('출발 시간이 변경되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    }
  }

  Future<void> _openKakaoChat(TaxiRoom room) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    await _supabaseService.joinTaxiRoom(room.id, userId);
    final String? url = room.chatUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('카카오톡 링크가 등록되지 않은 방입니다.')));
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

  void _showLocationMap(TaxiRoom room) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('상세 경로 확인', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF191F28))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(target: NLatLng((room.startLat + room.endLat) / 2, (room.startLng + room.endLng) / 2), zoom: 12),
                    scrollGesturesEnable: true, zoomGesturesEnable: true, tiltGesturesEnable: true, rotationGesturesEnable: true,
                  ),
                  forceGesture: true,
                  onMapReady: (controller) {
                    controller.addOverlayAll({
                      NMarker(id: 'start', position: NLatLng(room.startLat, room.startLng), caption: NOverlayCaption(text: '출발: ${room.startLocationName}'), iconTintColor: const Color(0xFF1B64DA)),
                      NMarker(id: 'end', position: NLatLng(room.endLat, room.endLng), caption: NOverlayCaption(text: '도착: ${room.endLocationName}'), iconTintColor: const Color(0xFFFF8C00)),
                    });
                    controller.updateCamera(NCameraUpdate.withParams(target: NLatLng((room.startLat + room.endLat) / 2, (room.startLng + room.endLng) / 2), zoom: 11));
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildLocationRow(Icons.radio_button_checked, const Color(0xFF1B64DA), room.startLocationName, '출발'),
            const SizedBox(height: 12),
            _buildLocationRow(Icons.location_on, const Color(0xFFFF8C00), room.endLocationName, '도착'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    const Color primaryOrange = Color(0xFFFF8C00);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text('택시 합승', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue, iconTheme: const IconThemeData(color: Colors.white), elevation: 4,
        actions: [
          IconButton(icon: Icon(_filterDate == null ? Icons.calendar_month : Icons.event_available, color: Colors.white), onPressed: _selectFilterDate),
          if (_filterDate != null) IconButton(icon: const Icon(Icons.filter_list_off, color: Colors.white), onPressed: () => setState(() => _filterDate = null)),
        ],
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryBlue, Color(0xFF1552B1)]))),
      ),
      body: Column(
        children: [
          if (_filterDate != null)
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20), color: primaryBlue.withAlpha(20),
              child: Text('${DateFormat('yyyy년 MM월 dd일').format(_filterDate!)} 검색 결과', style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          Expanded(
            child: StreamBuilder<List<TaxiRoom>>(
              stream: _supabaseService.getTaxiRooms(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('에러: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                var rooms = snapshot.data ?? [];
                
                // 차단된 사용자의 방 제외
                rooms = rooms.where((r) => !_blockedUserIds.contains(r.creatorId)).toList();

                if (_filterDate != null) {
                  rooms = rooms.where((r) => r.departureTime.year == _filterDate!.year && r.departureTime.month == _filterDate!.month && r.departureTime.day == _filterDate!.day).toList();
                }
                if (rooms.isEmpty) return const Center(child: Text('현재 개설된 방이 없습니다.', style: TextStyle(color: Color(0xFF8B95A1))));

                return ListView.builder(
                  itemCount: rooms.length, padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), physics: const BouncingScrollPhysics(),
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
                        color: Colors.white, borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: primaryBlue.withAlpha(60), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
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
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz, color: primaryBlue),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      onSelected: (value) {
                                        if (value == 'edit') _editRoomTime(room);
                                        else if (value == 'delete') _deleteRoom(room.id);
                                        else if (value == 'report') _showReportDialog(room);
                                        else if (value == 'block') _showBlockConfirmDialog(room.creatorId);
                                      },
                                      itemBuilder: (context) => [
                                        if (isCreator) ...[
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('시간 수정')])),
                                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('방 삭제', style: TextStyle(color: Colors.red))])),
                                        ],
                                        if (!isCreator) ...[
                                          const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.report, size: 18, color: Colors.orange), SizedBox(width: 8), Text('신고하기', style: TextStyle(color: Colors.orange))])),
                                          const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, size: 18, color: Colors.red), SizedBox(width: 8), Text('사용자 차단', style: TextStyle(color: Colors.red))])),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildLocationRow(Icons.radio_button_checked, primaryBlue, room.startLocationName, '출발'),
                                const SizedBox(height: 12),
                                _buildLocationRow(Icons.location_on, primaryOrange, room.endLocationName, '도착'),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () => _showLocationMap(room),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryBlue.withAlpha(100))),
                                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 16, color: primaryBlue), SizedBox(width: 8), Text('정확한 위치 보기', style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.bold))]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  _buildInfoChip(Icons.schedule, timeStr, const Color(0xFF4E5968)), const SizedBox(width: 8),
                                  _buildInfoChip(Icons.group, '${room.participants.length}/${room.maxPeople}명', isFull ? const Color(0xFFF04452) : const Color(0xFF4E5968)),
                                ]),
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: (isFull && !isParticipant) ? null : () => _openKakaoChat(room),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: (isFull && !isParticipant) ? Colors.grey[200] : Colors.amber.withAlpha(40), borderRadius: BorderRadius.circular(12), border: Border.all(color: (isFull && !isParticipant) ? Colors.grey : Colors.amber, width: 1)),
                                    child: Row(children: [
                                      Icon(Icons.chat_bubble, color: (isFull && !isParticipant) ? Colors.grey : Colors.amber, size: 18), const SizedBox(width: 6),
                                      Text((isFull && !isParticipant) ? '모집 완료' : '카톡 참여', style: TextStyle(color: (isFull && !isParticipant) ? Colors.grey : primaryBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoomScreen())),
        backgroundColor: primaryBlue, label: const Text('방 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180), fontWeight: FontWeight.bold)), Text(location, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF191F28)))]))
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(60), width: 1)),
      child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))]),
    );
  }
}
