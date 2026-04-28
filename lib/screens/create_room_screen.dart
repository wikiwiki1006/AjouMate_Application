import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/supabase_service.dart';
import '../services/geocoding_service.dart';
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
  bool _isSearching = false;
  bool _isFrequentLoading = true;
  List<Map<String, dynamic>> _frequentLocations = [];

  bool get _isMapSupported => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadFrequentLocations();
  }

  Future<void> _loadFrequentLocations() async {
    try {
      final locs = await _supabaseService.getFrequentLocations();
      if (mounted) {
        setState(() {
          _frequentLocations = locs;
          _isFrequentLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFrequentLoading = false);
    }
  }

  Future<void> _searchLocation(bool isStart) async {
    final query = isStart ? _startNameController.text : _endNameController.text;
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색어를 입력해주세요.')));
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await GeocodingService.geocode(query);
      setState(() => _isSearching = false);
      if (results.isEmpty) { _showNoResultGuide(); return; }
      if (mounted) {
        showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) => _buildSearchResultSheet(isStart, results),
        );
      }
    } catch (e) { setState(() => _isSearching = false); }
  }

  Widget _buildSearchResultSheet(bool isStart, List<Map<String, dynamic>> results) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isStart ? '출발지 선택' : '목적지 선택', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
          const SizedBox(height: 16),
          Expanded(child: ListView.separated(itemCount: results.length, separatorBuilder: (context, index) => const Divider(), itemBuilder: (context, index) {
            final res = results[index];
            return ListTile(leading: const Icon(Icons.location_on, color: Colors.blueAccent), title: Text(res['name'] ?? ''), subtitle: Text(res['roadAddress'] ?? res['jibunAddress'] ?? ''), onTap: () { Navigator.pop(context); _moveToLocation(isStart, res['latLng'], res['name']); });
          })),
        ],
      ),
    );
  }

  void _showNoResultGuide() {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('검색 결과가 없습니다'),
      content: const Text('지도를 직접 움직여서 위치를 정해 보세요!'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
    ));
  }

  void _moveToLocation(bool isStart, NLatLng latLng, String name) {
    _mapController?.updateCamera(NCameraUpdate.withParams(target: latLng, zoom: 16));
    setState(() {
      if (isStart) { _startLatLng = latLng; _startNameController.text = name; if (_endLatLng == null) _activeMode = 'end'; } 
      else { _endLatLng = latLng; _endNameController.text = name; }
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

  Future<void> _confirmLocation() async {
    if (_mapController == null) return;
    final center = _mapController!.nowCameraPosition.target;
    final address = await GeocodingService.reverseGeocode(center.latitude, center.longitude);
    final displayName = address ?? "직접 지정한 위치";
    setState(() {
      if (_activeMode == 'start') { _startLatLng = center; _startNameController.text = displayName; if (_endLatLng == null) _activeMode = 'end'; } 
      else { _endLatLng = center; _endNameController.text = displayName; }
    });
    _updateMarkers();
  }

  void _createRoom() async {
    if (_startLatLng == null || _endLatLng == null || _startNameController.text.isEmpty || _endNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지도에서 출발지와 목적지를 확정해주세요.')));
      return;
    }

    // 0. UGC 가이드라인 동의 확인
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('커뮤니티 가이드라인 동의'),
        content: const Text(
          '택시 합승 방 생성 시 부적절한 콘텐츠(욕설, 비하, 광고 등)를 게시할 경우 '
          '서비스 이용이 제한될 수 있습니다. 이에 동의하십니까?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의 및 생성')),
        ],
      ),
    );

    if (agreed != true) return;

    setState(() => _isSearching = true);

    // 1. 시스템 풀에서 사용 가능한 링크 가져오기 (현재 사용 중인 링크 제외)
    String? finalChatUrl = await _supabaseService.getSequentialChatLink();
    
    // 2. 만약 시스템 링크가 없으면 직접 입력 요청
    if (finalChatUrl == null) {
      setState(() => _isSearching = false);
      if (mounted) {
        final manualUrl = await _showManualLinkDialog();
        if (manualUrl == null || manualUrl.isEmpty) {
          // 사용자가 취소했거나 입력을 안 함
          return;
        }
        finalChatUrl = manualUrl;
      }
    }

    if (finalChatUrl == null) return; // 최종적으로 링크가 없으면 종료

    final departure = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    
    // 현재 시간보다 이전인지 체크
    if (departure.isBefore(DateTime.now())) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발 시간이 현재 시간보다 이전일 수 없습니다. 시간을 다시 확인해주세요.'))
        );
      }
      return;
    }

    final newRoom = TaxiRoom(
      id: '', creatorId: _supabaseService.currentUserId ?? 'unknown', creatorName: '사용자',
      startLocationName: _startNameController.text, startLat: _startLatLng!.latitude, startLng: _startLatLng!.longitude,
      endLocationName: _endNameController.text, endLat: _endLatLng!.latitude, endLng: _endLatLng!.longitude,
      departureTime: departure, maxPeople: _maxPeople, participants: [_supabaseService.currentUserId ?? 'unknown'],
      createdAt: DateTime.now(),
      chatUrl: finalChatUrl,
    );

    try {
      setState(() => _isSearching = true);
      await _supabaseService.createTaxiRoom(newRoom);
      if (mounted) { 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('합승 방이 생성되었습니다!'))); 
      }
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e'))); 
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<String?> _showManualLinkDialog() async {
    final TextEditingController linkController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('시스템 링크 매진', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 사용 가능한 시스템 오픈채팅 링크가 모두 소진되었습니다.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text('직접 카카오톡 오픈채팅방을 만든 후 링크를 아래에 입력하여 방을 생성할 수 있습니다.', style: TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(
              controller: linkController,
              decoration: InputDecoration(
                hintText: 'https://open.kakao.com/o/...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final url = linkController.text.trim();
              if (url.isEmpty || !url.contains('open.kakao.com')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('올바른 오픈채팅 링크를 입력해주세요.')));
                return;
              }
              Navigator.pop(context, url);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B64DA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('입력 완료'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('위치 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          _buildInputArea(),
          if (_isFrequentLoading) 
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_frequentLocations.isNotEmpty) 
            _buildFrequentLocationsBar(),
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
                  Center(child: Padding(padding: const EdgeInsets.only(bottom: 40), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(onTap: _isSearching ? null : _confirmLocation, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: _activeMode == 'start' ? const Color(0xFF1B64DA) : Colors.red, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]), child: Text(_activeMode == 'start' ? '여기서 출발 확정' : '여기를 목적지로 확정', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 8),
                    Icon(Icons.location_on, size: 50, color: _activeMode == 'start' ? const Color(0xFF1B64DA) : Colors.red),
                  ]))),
                if (_isSearching) const Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(children: [
        _buildSearchField(_startNameController, '출발지 (ex. 원천동)', const Color(0xFF1B64DA), _activeMode == 'start', () => setState(() => _activeMode = 'start'), () => _searchLocation(true)),
        const SizedBox(height: 8),
        _buildSearchField(_endNameController, '목적지 (ex. 매탄동)', Colors.red, _activeMode == 'end', () => setState(() => _activeMode = 'end'), () => _searchLocation(false)),
      ]),
    );
  }

  Widget _buildFrequentLocationsBar() {
    return Container(
      height: 50, padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _frequentLocations.length,
        itemBuilder: (context, index) {
          final loc = _frequentLocations[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: Colors.grey[100], side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              label: Text(loc['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final address = loc['address'] ?? '';
                if (address.isNotEmpty) {
                  setState(() => _isSearching = true);
                  final results = await GeocodingService.geocode(address);
                  setState(() => _isSearching = false);
                  if (results.isNotEmpty) { _moveToLocation(_activeMode == 'start', results[0]['latLng'], loc['name']); }
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, Color color, bool isActive, VoidCallback onTap, VoidCallback onSearch) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: isActive ? color.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isActive ? color : Colors.transparent, width: 1.5)), child: Row(children: [
      Icon(isActive ? Icons.circle : Icons.circle_outlined, size: 14, color: color),
      const SizedBox(width: 12),
      Expanded(child: TextField(controller: controller, onTap: onTap, onSubmitted: (_) => onSearch(), textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: hint, border: InputBorder.none, hintStyle: const TextStyle(fontSize: 13, color: Colors.grey)))),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return value.text.isNotEmpty
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                  onPressed: () => controller.clear(),
                )
              : const SizedBox.shrink();
        },
      ),
      const SizedBox(width: 8),
      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.search, size: 22), onPressed: onSearch),
    ])));
  }

  Widget _buildBottomArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  '날짜',
                  '${_selectedDate.month}월 ${_selectedDate.day}일',
                  _selectDate,
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(
                  '시간',
                  _selectedTime.format(context),
                  _selectTime,
                  Icons.access_time,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_outlined, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('최대 인원', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4E5968))),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _maxPeople > 2 ? () => setState(() => _maxPeople--) : null,
                    ),
                    Text(
                      '$_maxPeople',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _maxPeople < 4 ? () => setState(() => _maxPeople++) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF1B64DA)),
              SizedBox(width: 6),
              Text(
                '방 생성 시 자동으로 카카오 오픈채팅방이 할당됩니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF1B64DA), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B64DA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('방 만들기 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF1B64DA)),
                const SizedBox(width: 6),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF191F28))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectDate() async { final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7))); if (p != null) setState(() => _selectedDate = p); }
  
  void _selectTime() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('취소', style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('확인', style: TextStyle(color: Color(0xFF1B64DA), fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                ),
                onDateTimeChanged: (DateTime newDateTime) {
                  setState(() {
                    _selectedTime = TimeOfDay.fromDateTime(newDateTime);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
