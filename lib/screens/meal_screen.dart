import 'package:flutter/material.dart';
import '../services/meal_service.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MealService _mealService = MealService();
  Map<String, dynamic>? _weeklyMeals;
  bool _isLoading = true;
  String? _selectedDateKey;
  List<String> _dateKeys = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    setState(() => _isLoading = true);
    try {
      final data = await _mealService.getWeeklyMeals();
      if (mounted && data != null) {
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final keys = data.keys.toList();
        final filteredKeys = keys.where((key) {
          final match = RegExp(r'\((\d{4}-\d{2}-\d{2})\)').firstMatch(key);
          return match != null && match.group(1)!.compareTo(todayStr) >= 0;
        }).toList();
        filteredKeys.sort((a, b) {
          final dateA = RegExp(r'\((\d{4}-\d{2}-\d{2})\)').firstMatch(a)?.group(1) ?? "";
          final dateB = RegExp(r'\((\d{4}-\d{2}-\d{2})\)').firstMatch(b)?.group(1) ?? "";
          return dateA.compareTo(dateB);
        });
        final displayKeys = filteredKeys.take(5).toList();
        setState(() { _weeklyMeals = data; _dateKeys = displayKeys; _selectedDateKey = displayKeys.isNotEmpty ? displayKeys.first : null; _isLoading = false; });
      } else { setState(() => _isLoading = false); }
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 식단', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [Tab(text: '기숙사 식당'), Tab(text: '교직원 식당')],
        ),
      ),
      body: Column(
        children: [
          if (!_isLoading && _dateKeys.isNotEmpty) _buildDateSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_weeklyMeals == null || _selectedDateKey == null)
                    ? const Center(child: Text('식단 정보가 없습니다.'))
                    : TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [_buildMealList('dormitory'), _buildMealList('staff')],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    const Color primaryBlue = Color(0xFF1B64DA);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFFF2F4F6),
      child: Row(
        children: _dateKeys.map((key) {
          final isSelected = _selectedDateKey == key;
          String day = "";
          String dateNum = "";
          final match = RegExp(r'(\S+)\s+\(\d{4}-\d{2}-(\d{2})\)').firstMatch(key);
          if (match != null) { day = match.group(1)!; dateNum = match.group(2)!; }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDateKey = key),
              child: Column(
                children: [
                  Text(day, style: TextStyle(fontSize: 12, color: isSelected ? primaryBlue : const Color(0xFF4E5968))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
                      border: isSelected ? null : Border.all(color: Colors.black.withAlpha(20), width: 1),
                    ),
                    child: Text(dateNum, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF191F28))),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealList(String cafeType) {
    const Color primaryBlue = Color(0xFF1B64DA);
    final dayData = _weeklyMeals![_selectedDateKey]?[cafeType] as Map<String, dynamic>?;
    if (dayData == null) return const Center(child: Text('정보 없음'));

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // 교직원 식당일 경우 아침 창 대신 운영시간 문구 표시
        if (cafeType == 'staff')
          _buildInfoCard('교직원식당 운영시간', '중식: 11:30 ~ 13:30\n석식: 17:30 ~ 19:00', primaryBlue)
        else if (dayData.containsKey('breakfast'))
          _buildMealCard('아침', Icons.wb_sunny_outlined, dayData['breakfast'], primaryBlue),
          
        _buildMealCard('점심', Icons.wb_sunny, dayData['lunch'], const Color(0xFFFF8C00)),
        _buildMealCard('저녁', Icons.nights_stay, dayData['dinner'], const Color(0xFF333D4B)),
        if (dayData.containsKey('snack'))
          _buildMealCard('분식', Icons.fastfood, dayData['snack'], const Color(0xFFF04452)),
      ],
    );
  }

  Widget _buildMealCard(String title, IconData icon, String? menu, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withAlpha(35), 
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: color.withAlpha(60), width: 1)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              (menu == null || menu.contains('정보 없음')) ? '등록된 식단이 없습니다.' : menu,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF191F28), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(40), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF4E5968), height: 1.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
