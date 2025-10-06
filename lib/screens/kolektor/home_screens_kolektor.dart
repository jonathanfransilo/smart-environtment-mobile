import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pengambilan_sampah_screen.dart';
import '../../services/pickup_service.dart';

class HomeScreensKolektor extends StatefulWidget {
  const HomeScreensKolektor({super.key});

  @override
  State<HomeScreensKolektor> createState() => _HomeScreensKolektorState();
}

class _HomeScreensKolektorState extends State<HomeScreensKolektor> {
  List<Map<String, dynamic>> pengambilanList = [];

  @override
  void initState() {
    super.initState();
    _loadPengambilanData();
  }

  Future<void> _loadPengambilanData() async {
    final data = await PickupService.getPickupHistory();
    if (mounted) {
      setState(() {
        pengambilanList = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF009688);
    final TextStyle titleStyle = GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );

    // Dummy data daftar tugas
    final List<Map<String, dynamic>> tugasList = [
      {
        "name": "Davina Ajah",
        "address": "Jl. Raya Menteng no. 11 RT05 / RW03",
        "distance": "10 Km/dt",
        "time": "50m",
        "latitude": -6.200000,
        "longitude": 106.816666,
      },
      {
        "name": "Rahmat Darmawan",
        "address": "Jl. Gatot Subroto no. 2, Jakarta",
        "distance": "20 Km/dt",
        "time": "60m",
        "latitude": -6.215000,
        "longitude": 106.830000,
      },
      {
        "name": "Putri Amelia",
        "address": "Jl. Sudirman No. 5, Jakarta",
        "distance": "15 Km/dt",
        "time": "45m",
        "latitude": -6.210000,
        "longitude": 106.825000,
      },
    ];

    // Data pengambilan terakhir akan dimuat dari PickupService

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundImage: AssetImage("assets/images/profile.jpg"),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Raka Juliandra",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF009688),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Menteng, Jakarta Pusat",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined, size: 26),
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        const CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage("assets/images/profile.jpg"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card Ringkasan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Tugas Hari Ini",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "12 Mei 2025",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem("50", "Total"),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            _statItem("30", "Selesai"),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            _statItem("20", "Belum"),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Daftar Tugas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daftar Tugas", style: titleStyle),
                    Text(
                      "Lainnya",
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                itemCount: tugasList.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final tugas = tugasList[index];
                  return _taskCard(
                    tugas["name"],
                    tugas["address"],
                    tugas["distance"],
                    tugas["time"],
                    tugas["latitude"],
                    tugas["longitude"],
                    primaryColor,
                    context,
                  );
                },
              ),

              const SizedBox(height: 24),

              // Pengambilan Terakhir
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pengambilan Terakhir", style: titleStyle),
                    Text(
                      "Lainnya",
                      style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 180,
                child: pengambilanList.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada pengambilan sampah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: pengambilanList.length,
                        itemBuilder: (context, index) {
                          final item = pengambilanList[index];
                          return _pickupCard(
                            item["name"]?.toString() ?? "",
                            item["address"]?.toString() ?? "",
                            "Rp. ${(item["totalPrice"] as num?)?.toInt() ?? 0}",
                            item["image"]?.toString() ?? "assets/images/dummy.jpg",
                            primaryColor,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _taskCard(String name, String address, String distance, String time, double latitude, double longitude, Color primaryColor, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "•$time",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.green[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distance,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PengambilanSampahScreen(
                      userName: name,
                      userPhone: '+6285943643645',
                      address: address,
                      idPengambilan: '#CLUAP09141441',
                      distance: distance,
                      time: time,
                      latitude: latitude,
                      longitude: longitude,
                    ),
                  ),
                ).then((_) {
                  // Refresh pengambilan list when returning from pengambilan screen
                  _loadPengambilanData();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                "Ambil",
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _pickupCard(String name, String address, String price, String image, Color primaryColor) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.asset(
              image,
              height: 180,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  width: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Detail",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
