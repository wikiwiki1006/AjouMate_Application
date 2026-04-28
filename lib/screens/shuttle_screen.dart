import 'package:flutter/material.dart';
import 'dart:async';
import '../services/supabase_service.dart';

class ShuttleScreen extends StatefulWidget {
  const ShuttleScreen({super.key});

  @override
  State<ShuttleScreen> createState() => _ShuttleScreenState();
}

class _ShuttleScreenState extends State<ShuttleScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late Timer _timer;
  DateTime _now = DateTime.now();
  late TabController _tabController;
  
  String? _selectedTime;
  String? _selectedStation;
  String? _selectedType;
  String? _selectedInfo;

  Map<String, Map<String, List<Map<String, String>>>> shuttleData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTimetable();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadTimetable() async {
    final data = await _supabaseService.getShuttleTimetable();
    if (mounted) {
      setState(() {
        shuttleData = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String? _getNextShuttle(List<Map<String, String>> shuttleList) {
    final nowStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    for (var shuttle in shuttleList) { 
      final time = shuttle['time']!;
      if (time.compareTo(nowStr) >= 0) return time; 
    }
    return null;
  }

  String _getRemainingTime(String targetTime) {
    final parts = targetTime.split(':');
    final target = DateTime(_now.year, _now.month, _now.day, int.parse(parts[0]), int.parse(parts[1]));
    Duration diff = target.difference(_now);
    if (diff.isNegative) return "출발함";
    int hours = diff.inHours;
    int minutes = diff.inMinutes % 60;
    return hours > 0 ? '$hours시간 $minutes분 남음' : '$minutes분 남음';
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (shuttleData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('셔틀 시간표', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: primaryBlue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('데이터를 불러올 수 없습니다. 다시 시도해주세요.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text('셔틀 시간표', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [Tab(text: '광교중앙역'), Tab(text: '수원역')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [_buildShuttleList('광교중앙역'), _buildShuttleList('수원역')],
      ),
      bottomNavigationBar: _selectedTime != null ? _buildSelectionDetail() : null,
    );
  }

  Widget _buildShuttleList(String station) {
    final data = shuttleData[station] ?? {'등교': [], '하교': []};
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHighlightGuide(),
        const SizedBox(height: 20),
        _buildShuttleCard('등교 (학교행)', data['등교']!, station, '등교', const Color(0xFF1B64DA)),
        const SizedBox(height: 20),
        _buildShuttleCard('하교 (역행)', data['하교']!, station, '하교', const Color(0xFFFF8C00)),
        const SizedBox(height: 32),
        _buildInfoCard(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildShuttleCard(String title, List<Map<String, String>> shuttleList, String station, String type, Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: themeColor.withAlpha(40), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: themeColor.withAlpha(20),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
              border: Border(bottom: BorderSide(color: themeColor.withAlpha(40), width: 1)),
            ),
            child: Row(
              children: [
                Icon(type == '등교' ? Icons.school : Icons.home, color: themeColor, size: 20),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildTimeGrid(shuttleList, station, type, themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(List<Map<String, String>> shuttleList, String station, String type, Color themeColor) {
    final nextShuttle = _getNextShuttle(shuttleList);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemCount: shuttleList.length,
      itemBuilder: (context, index) {
        final shuttle = shuttleList[index];
        final time = shuttle['time']!;
        final info = shuttle['info']!;
        final isNext = time == nextShuttle;
        final isSelected = _selectedTime == time && _selectedStation == station && _selectedType == type;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) { 
                _selectedTime = null; _selectedStation = null; _selectedType = null; _selectedInfo = null;
              } else { 
                _selectedTime = time; _selectedStation = station; _selectedType = type; _selectedInfo = info;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? themeColor : (isNext ? themeColor.withAlpha(30) : const Color(0xFFF2F4F6)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? themeColor : (isNext ? themeColor.withAlpha(100) : Colors.transparent), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 15,
                fontWeight: (isNext || isSelected) ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isNext ? themeColor : const Color(0xFF4E5968)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionDetail() {
    const Color primaryBlue = Color(0xFF1B64DA);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: primaryBlue.withAlpha(30), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_selectedStation (${_selectedType == '등교' ? '학교행' : '역행'})', style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$_selectedTime 출발', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF191F28))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFF8C00).withAlpha(30), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF8C00).withAlpha(100))),
                child: Text(_getRemainingTime(_selectedTime!), style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 40, color: Color(0xFFF2F4F6), thickness: 1.5),
          Row(
            children: [
              const Icon(Icons.location_on, color: primaryBlue, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text((_selectedInfo ?? '').replaceAll('\\n', '\n'), style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF4E5968), fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => setState(() { _selectedTime = null; _selectedInfo = null; }),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2F4F6), foregroundColor: const Color(0xFF4E5968), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1B64DA).withAlpha(30), width: 1)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF1B64DA), size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('색상이 있는 시간은 가장 빠르게 탈 수 있는 버스입니다.', style: TextStyle(fontSize: 13, color: Color(0xFF4E5968), fontWeight: FontWeight.bold))),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.touch_app_outlined, color: Color(0xFF1B64DA), size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('시간을 클릭하면 출발/도착 장소를 확인할 수 있습니다.', style: TextStyle(fontSize: 13, color: Color(0xFF4E5968), fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black12)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('운행 안내', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191F28), fontSize: 15)),
          SizedBox(height: 10),
          Text('• 주말 및 공휴일은 운행하지 않습니다.', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
          Text('• 도로 사정에 따라 시간이 변동될 수 있습니다.', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
        ],
      ),
    );
  }
}
