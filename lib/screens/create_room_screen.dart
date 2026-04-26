import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/supabase_service.dart';
import '../models/taxi_room.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _maxPeople = 4;

  NLatLng? _startLatLng;
  NLatLng? _endLatLng;
  bool _isSelectingStart = true;

  bool get _isMapSupported => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _createRoom() async {
    if (!_isMapSupported) {
      _startLatLng ??= const NLatLng(37.2831, 127.0448);
      _endLatLng ??= const NLatLng(37.2844, 127.0444);
    }

    if (_startController.text.isEmpty || _endController.text.isEmpty || _startLatLng == null || _endLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('출발지와 목적지 이름을 입력해주세요.')));
      return;
    }

    final departure = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final userId = _supabaseService.currentUserId ?? 'unknown';
    
    final newRoom = TaxiRoom(
      id: '',
      creatorId: userId,
      creatorName: '사용자',
      startLocationName: _startController.text,
      startLat: _startLatLng!.latitude,
      startLng: _startLatLng!.longitude,
      endLocationName: _endController.text,
      endLat: _endLatLng!.latitude,
      endLng: _endLatLng!.longitude,
      departureTime: departure,
      maxPeople: _maxPeople,
      participants: [userId],
      createdAt: DateTime.now(),
    );

    try {
      await _supabaseService.createTaxiRoom(newRoom);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('방이 생성되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    return Scaffold(
      appBar: AppBar(
        title: const Text('합승 방 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: _isMapSupported
                  ? NaverMap(
                      options: const NaverMapViewOptions(initialCameraPosition: NCameraPosition(target: NLatLng(37.2831, 127.0448), zoom: 14)),
                      onMapTapped: (point, latLng) {
                        setState(() {
                          if (_isSelectingStart) {
                            _startLatLng = latLng;
                          } else {
                            _endLatLng = latLng;
                          }
                        });
                      },
                    )
                  : Container(color: Colors.grey[200], child: const Center(child: Text('지도는 모바일 기기에서 지원됩니다.'))),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: ElevatedButton(onPressed: () => setState(() => _isSelectingStart = true), style: ElevatedButton.styleFrom(backgroundColor: _isSelectingStart ? primaryBlue : Colors.white, foregroundColor: _isSelectingStart ? Colors.white : primaryBlue, side: BorderSide(color: primaryBlue.withAlpha(50))), child: const Text('출발지 선택'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: () => setState(() => _isSelectingStart = false), style: ElevatedButton.styleFrom(backgroundColor: !_isSelectingStart ? primaryBlue : Colors.white, foregroundColor: !_isSelectingStart ? Colors.white : primaryBlue, side: BorderSide(color: primaryBlue.withAlpha(50))), child: const Text('목적지 선택'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _startController, decoration: const InputDecoration(labelText: '출발지 이름', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _endController, decoration: const InputDecoration(labelText: '목적지 이름', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  _buildListTile('출발 날짜', "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}", _selectDate),
                  _buildListTile('출발 시간', '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}', _selectTime),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('최대 인원', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      DropdownButton<int>(value: _maxPeople, items: [2, 3, 4].map((v) => DropdownMenuItem(value: v, child: Text('$v명'))).toList(), onChanged: (v) => setState(() => _maxPeople = v!)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _createRoom, style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('방 만들기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Text(value, style: const TextStyle(color: Color(0xFF1B64DA), fontWeight: FontWeight.bold, fontSize: 16)),
      onTap: onTap,
    );
  }
}
