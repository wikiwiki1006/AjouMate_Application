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
  final TextEditingController _startNameController = TextEditingController();
  final TextEditingController _endNameController = TextEditingController();
  
  NaverMapController? _mapController;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _maxPeople = 4;

  NLatLng? _startLatLng;
  NLatLng? _endLatLng;
  
  String _activeMode = 'start'; 
  bool _isMapLoading = true;

  bool get _isMapSupported => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  // DB에서 장소 검색 로직
  Future<void> _searchLocationFromDB(bool isStart) async {
    final query = isStart ? _startNameController.text : _endNameController.text;
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색어를 입력해주세요.')));
      return;
    }

    final results = await _supabaseService.searchLocations(query);
    
    if (results.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록된 장소가 없습니다. 직접 지도를 이동해 찍어주세요.')));
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('장소 선택 (DB)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final loc = results[index];
                    return ListTile(
                      leading: const Icon(Icons.place, color: Colors.blue),
                      title: Text(loc['name']),
                      onTap: () {
                        Navigator.pop(context);
                        final latLng = NLatLng(loc['lat'], loc['lng']);
                        _moveToLocation(isStart, latLng, loc['name']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _moveToLocation(bool isStart, NLatLng latLng, String name) {
    _mapController?.updateCamera(NCameraUpdate.withParams(target: latLng, zoom: 16));
    setState(() {
      if (isStart) {
        _startLatLng = latLng;
        _startNameController.text = name;
        _activeMode = 'end';
      } else {
        _endLatLng = latLng;
        _endNameController.text = name;
      }
    });
    _updateMarkers();
  }

  void _updateMarkers() {
    if (_mapController == null) return;
    _mapController!.clearOverlays();
    if (_startLatLng != null) {
      _mapController!.addOverlay(NMarker(id: 'start', position: _startLatLng!, caption: NOverlayCaption(text: "출발: ${_startNameController.text}"), iconTintColor: const Color(0xFF1B64DA)));
    }
    if (_endLatLng != null) {
      _mapController!.addOverlay(NMarker(id: 'end', position: _endLatLng!, caption: NOverlayCaption(text: "도착: ${_endNameController.text}"), iconTintColor: Colors.red));
    }
  }

  void _confirmLocation() {
    if (_mapController == null) return;
    final center = _mapController!.nowCameraPosition.target;
    setState(() {
      if (_activeMode == 'start') {
        _startLatLng = center;
        if (_startNameController.text.isEmpty) _startNameController.text = "선택된 출발지";
        _activeMode = 'end';
      } else {
        _endLatLng = center;
        if (_endNameController.text.isEmpty) _endNameController.text = "선택된 목적지";
      }
    });
    _updateMarkers();
  }

  void _createRoom() async {
    if (_startLatLng == null || _endLatLng == null || _startNameController.text.isEmpty || _endNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지도에서 위치를 확정하고 장소 이름을 입력해주세요.')));
      return;
    }
    final departure = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final newRoom = TaxiRoom(
      id: '', creatorId: _supabaseService.currentUserId ?? 'unknown', creatorName: '사용자',
      startLocationName: _startNameController.text, startLat: _startLatLng!.latitude, startLng: _startLatLng!.longitude,
      endLocationName: _endNameController.text, endLat: _endLatLng!.latitude, endLng: _endLatLng!.longitude,
      departureTime: departure, maxPeople: _maxPeople, participants: [_supabaseService.currentUserId ?? 'unknown'],
      createdAt: DateTime.now(),
    );
    try {
      await _supabaseService.createTaxiRoom(newRoom);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('합승 방이 생성되었습니다!'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('장소 선택 (API 미사용)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
      ),
      body: Column(
        children: [
          _buildInputArea(),
          Expanded(
            child: Stack(
              children: [
                if (_isMapSupported)
                  NaverMap(
                    options: const NaverMapViewOptions(initialCameraPosition: NCameraPosition(target: NLatLng(37.2831, 127.0448), zoom: 15), locationButtonEnable: true),
                    onMapReady: (controller) { setState(() { _mapController = controller; _isMapLoading = false; }); _updateMarkers(); },
                  )
                else
                  Container(color: Colors.grey[100], child: const Center(child: Text('지도는 모바일에서 지원됩니다.'))),
                
                if (!_isMapLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _confirmLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: _activeMode == 'start' ? const Color(0xFF1B64DA) : Colors.red, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
                              child: Text(_activeMode == 'start' ? '여기서 출발 확정' : '여기를 목적지로 확정', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(Icons.location_on, size: 50, color: _activeMode == 'start' ? const Color(0xFF1B64DA) : Colors.red),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildBottomArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          _buildSearchField(_startNameController, '출발지 검색 또는 입력', const Color(0xFF1B64DA), _activeMode == 'start', () => setState(() => _activeMode = 'start'), () => _searchLocationFromDB(true)),
          const SizedBox(height: 10),
          _buildSearchField(_endNameController, '목적지 검색 또는 입력', Colors.red, _activeMode == 'end', () => setState(() => _activeMode = 'end'), () => _searchLocationFromDB(false)),
        ],
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, Color color, bool isActive, VoidCallback onTap, VoidCallback onSearch) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: isActive ? color.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isActive ? color : Colors.transparent, width: 1.5)),
        child: Row(
          children: [
            Icon(isActive ? Icons.circle : Icons.circle_outlined, size: 14, color: color),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: controller, onTap: onTap, decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: const TextStyle(fontSize: 13)))),
            IconButton(icon: const Icon(Icons.search, size: 20), onPressed: onSearch),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem('날짜', '${_selectedDate.month}/${_selectedDate.day}', _selectDate),
              _buildInfoItem('시간', '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}', _selectTime),
              DropdownButton<int>(value: _maxPeople, items: [2, 3, 4].map((v) => DropdownMenuItem(value: v, child: Text('$v명'))).toList(), onChanged: (v) => setState(() => _maxPeople = v!)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _createRoom, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B64DA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('방 만들기 완료'))),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]));
  }

  void _selectDate() async { final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7))); if (p != null) setState(() => _selectedDate = p); }
  void _selectTime() async { final p = await showTimePicker(context: context, initialTime: _selectedTime); if (p != null) setState(() => _selectedTime = p); }
}
