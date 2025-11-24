import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class JadwalPengambilanScreen extends StatefulWidget {
  final int? serviceAccountId;

  const JadwalPengambilanScreen({
    super.key,
    this.serviceAccountId,
  });

  @override
  State<JadwalPengambilanScreen> createState() =>
      _JadwalPengambilanScreenState();
}

class _JadwalPengambilanScreenState extends State<JadwalPengambilanScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  
  // Highlighted dates (dates with schedules)
  Set<int> _scheduleDates = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));

    // DUMMY DATA - Generate jadwal untuk bulan ini
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final daysInMonth = nextMonth.difference(currentMonth).inDays;
    
    final Set<int> dates = {};
    final List<Map<String, dynamic>> allSchedules = [];
    
    // Generate dummy schedules untuk setiap hari Senin dan Kamis di bulan ini
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      
      // Hanya Senin (1) dan Kamis (4)
      if (date.weekday == 1 || date.weekday == 4) {
        dates.add(day);
        
        final dayName = _getDayName(date.weekday);
        final time = date.weekday == 1 ? '08:00' : '14:00'; // Senin pagi, Kamis siang
        
        allSchedules.add({
          'date': date,
          'day': dayName,
          'time': time,
          'status': 'scheduled',
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _scheduleDates = dates;
        _schedules = allSchedules;
        _isLoading = false;
      });
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    return days[weekday - 1];
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
    _loadSchedules();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDate = null;
    });
    _loadSchedules();
  }

  void _selectDate(int day) {
    setState(() {
      _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    });
  }

  List<Map<String, dynamic>> _getFilteredSchedules() {
    if (_selectedDate == null) {
      return _schedules;
    }
    
    return _schedules.where((schedule) {
      final scheduleDate = schedule['date'] as DateTime;
      return scheduleDate.day == _selectedDate!.day &&
          scheduleDate.month == _selectedDate!.month &&
          scheduleDate.year == _selectedDate!.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Jadwal Pengambilan',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading ? _buildShimmer() : _buildContent(primaryColor),
    );
  }

  Widget _buildContent(Color primaryColor) {
    // Format month name manually untuk menghindari issue dengan locale
    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthName = monthNames[_selectedMonth.month - 1];
    final yearName = _selectedMonth.year.toString();
    
    return Column(
      children: [
        // Calendar Section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$monthName $yearName',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: primaryColor),
                        onPressed: _previousMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: primaryColor),
                        onPressed: _nextMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Day Headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
                    .map((day) => SizedBox(
                          width: 48,
                          child: Center(
                            child: Text(
                              day,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              
              // Calendar Grid
              _buildCalendarGrid(primaryColor),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Schedule List Section
        Expanded(
          child: Container(
            color: Colors.white,
            child: _buildScheduleList(primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Color primaryColor) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // KALENDER INDONESIA: Minggu sebagai hari pertama
    // Header: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
    // Index:    0      1      2      3      4      5      6
    //
    // DateTime.weekday (ISO 8601):
    // Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7
    //
    // Konversi ke index kalender Indonesia (Minggu=0):
    final int startWeekday = firstDayOfMonth.weekday % 7;
    
    // Build grid dengan 6 baris x 7 kolom (42 cells total)
    List<Widget> calendarCells = [];
    
    // Tambah empty cells sebelum tanggal 1
    for (int i = 0; i < startWeekday; i++) {
      calendarCells.add(_buildEmptyCell());
    }
    
    // Tambah cells untuk setiap tanggal
    for (int day = 1; day <= daysInMonth; day++) {
      calendarCells.add(_buildDayCell(day, primaryColor));
    }
    
    // Tambah empty cells untuk melengkapi grid 6x7 (42 cells)
    final totalCells = calendarCells.length;
    final remainingCells = (6 * 7) - totalCells;
    for (int i = 0; i < remainingCells; i++) {
      calendarCells.add(_buildEmptyCell());
    }
    
    // Buat 6 baris, masing-masing 7 kolom
    List<Widget> rows = [];
    for (int row = 0; row < 6; row++) {
      final startIndex = row * 7;
      final endIndex = startIndex + 7;
      
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: calendarCells.sublist(startIndex, endIndex),
          ),
        ),
      );
    }
    
    return Column(children: rows);
  }
  
  Widget _buildEmptyCell() {
    return const SizedBox(width: 48, height: 48);
  }
  
  Widget _buildDayCell(int day, Color primaryColor) {
    final hasSchedule = _scheduleDates.contains(day);
    final isSelected = _selectedDate?.day == day &&
        _selectedDate?.month == _selectedMonth.month &&
        _selectedDate?.year == _selectedMonth.year;
    final isToday = DateTime.now().day == day &&
        DateTime.now().month == _selectedMonth.month &&
        DateTime.now().year == _selectedMonth.year;

    return GestureDetector(
      onTap: hasSchedule ? () => _selectDate(day) : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : hasSchedule
                    ? primaryColor.withOpacity(0.1)
                    : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !isSelected
                ? Border.all(color: primaryColor, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              day.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: hasSchedule || isToday ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList(Color primaryColor) {
    final filteredSchedules = _getFilteredSchedules();

    if (filteredSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada jadwal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDate != null
                  ? 'Pilih tanggal lain yang ditandai'
                  : 'Belum ada jadwal untuk bulan ini',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredSchedules.length,
      itemBuilder: (context, index) {
        final schedule = filteredSchedules[index];
        final date = schedule['date'] as DateTime;
        final day = schedule['day'] as String;
        final time = schedule['time'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${date.day.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            title: Text(
              day,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            trailing: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Column(
      children: [
        // Calendar Shimmer
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Month header shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 120, height: 20),
                  Row(
                    children: [
                      _shimmerBox(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 16),
                      _shimmerBox(width: 24, height: 24, radius: 12),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Day headers shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  7,
                  (index) => _shimmerBox(width: 30, height: 14),
                ),
              ),
              const SizedBox(height: 12),
              
              // Calendar grid shimmer
              Column(
                children: List.generate(
                  5,
                  (rowIndex) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        7,
                        (colIndex) => _shimmerBox(
                          width: 36,
                          height: 36,
                          radius: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Schedule list shimmer
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      _shimmerBox(width: 48, height: 48, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _shimmerBox(width: 80, height: 16),
                            const SizedBox(height: 6),
                            _shimmerBox(width: 60, height: 14),
                          ],
                        ),
                      ),
                      _shimmerBox(width: 4, height: 40, radius: 2),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
