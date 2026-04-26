import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notice_service.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final NoticeService _noticeService = NoticeService();
  List<Map<String, dynamic>> _allNotices = [];
  List<Map<String, dynamic>> _filteredNotices = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  static const int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  List<Map<String, dynamic>> get _pagedNotices {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredNotices.length) return [];
    return _filteredNotices.sublist(startIndex, endIndex > _filteredNotices.length ? _filteredNotices.length : endIndex);
  }

  int get _totalPages => (_filteredNotices.length / _itemsPerPage).ceil();

  Future<void> _fetchNotices() async {
    setState(() { _isLoading = true; _currentPage = 1; });
    try {
      final List<dynamic> data = await _noticeService.loadNotices();
      final List<Map<String, dynamic>> notices = data.map((item) => Map<String, dynamic>.from(item)).toList();
      if (mounted) setState(() { _allNotices = notices; _filteredNotices = notices; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _filterNotices(String query) {
    setState(() {
      _currentPage = 1;
      if (query.isEmpty) { _filteredNotices = _allNotices; }
      else {
        final cleanQuery = query.replaceAll(' ', '').toLowerCase();
        final filtered = _allNotices.where((n) => (n['title'] ?? '').replaceAll(' ', '').toLowerCase().contains(cleanQuery)).toList();
        filtered.sort((a, b) {
          if (a['is_pinned'] == true && b['is_pinned'] != true) return -1;
          if (a['is_pinned'] != true && b['is_pinned'] == true) return 1;
          return 0;
        });
        _filteredNotices = filtered;
      }
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1B64DA);
    return Scaffold(
      appBar: AppBar(
        title: const Text('학교 공지사항', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterNotices,
              decoration: InputDecoration(
                hintText: '공지사항 검색...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B95A1)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.black12, width: 1)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.black12, width: 1)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _pagedNotices.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    // 구분선 더 진하게 수정
                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1.0, color: Colors.black26),
                    itemBuilder: (context, index) {
                      final notice = _pagedNotices[index];
                      final isPinned = notice['is_pinned'] == true;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          // 고정 공지 배경색을 더 연하게 수정 (Alpha 40 -> 20)
                          color: isPinned ? primaryBlue.withAlpha(20) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isPinned ? primaryBlue.withAlpha(60) : Colors.transparent, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _launchUrl(notice['link'] ?? ''),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                if (isPinned)
                                  Padding(padding: const EdgeInsets.only(right: 14), child: Icon(Icons.push_pin, size: 22, color: primaryBlue)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notice['title'] ?? '제목 없음',
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: isPinned ? FontWeight.bold : FontWeight.w600,
                                          color: isPinned ? primaryBlue : const Color(0xFF191F28),
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_month_outlined, size: 14, color: const Color(0xFF8B95A1)),
                                          const SizedBox(width: 6),
                                          Text(notice['date'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF8B95A1), fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: const Color(0xFFD1D6DB)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_isLoading && _totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF2F4F6), width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage = 1) : null, icon: const Icon(Icons.first_page, size: 28)),
          TextButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null, child: const Text('이전', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          const SizedBox(width: 20),
          Text('$_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 20),
          TextButton(onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null, child: const Text('다음', style: TextStyle(color: Color(0xFF1B64DA), fontSize: 15, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
