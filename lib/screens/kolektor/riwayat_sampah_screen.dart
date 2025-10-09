import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiwayatSampahScreen extends StatelessWidget {
  final Map<String, dynamic> pickupData;

  const RiwayatSampahScreen({
    super.key,
    required this.pickupData,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(pickupData['items'] ?? []);
    
    // Group items by category
    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in items) {
      String category = item['category'] ?? 'Lainnya';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Pengambilan Sampah',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header dengan Icon Check
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Pengambilan Sampah',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Photo Section
            Container(
              margin: EdgeInsets.all(20),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: pickupData['image'] != null && pickupData['image'].toString().startsWith('http')
                ? Image.network(
                    pickupData['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/dummy.jpg',
                        fit: BoxFit.cover,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  )
                : Image.asset(
                    pickupData['image'] ?? 'assets/images/dummy.jpg',
                    fit: BoxFit.cover,
                  ),
            ),
            
            // Address and ID
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    pickupData['address'] ?? 'Alamat tidak tersedia',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    pickupData['idPengambilan'] ?? '#ID000000',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Waktu Pengambilan
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Pengambilan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    pickupData['date'] ?? 'Tanggal tidak tersedia',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Sampah Section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampah',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Sampah Items by Category
                  for (var entry in groupedItems.entries) ...[
                    // Category Header
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Sampah ${entry.key}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    
                    // Items in this category
                    for (var item in entry.value)
                      Container(
                        margin: EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['name'] ?? 'Item tidak diketahui',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${item['quantity'] ?? 0}x',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 16),
                  ],
                  
                  // Total Items
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jumlah',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${_getTotalQuantity(items)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  int _getTotalQuantity(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      total += (item['quantity'] as int? ?? 0);
    }
    return total;
  }
}