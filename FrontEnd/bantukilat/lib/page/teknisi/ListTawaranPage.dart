import 'package:bantukilat/page/DetailTawaran.dart';
import 'package:bantukilat/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

// ============================================================================
// 1. DEFINISI KATEGORI TAWARAN (ENUM)
// ============================================================================
enum OfferCategory {
  darurat,
  kelistrikan,
  saluranAir,
  atapDinding,
  kunciPintu,
  teknologi,
  kendaraan,
  angkutBarang,
  bantuanLainnya,
}

// ============================================================================
// 2. HELPER KONFIGURASI WARNA & LABEL KATEGORI
// Mengambil warna container dan warna teks/icon sesuai daftar KategoriLayananCard
// ============================================================================
class CategoryStyle {
  final String filterLabel; // Label pada deretan chip filter atas
  final String badgeTitle; // Judul yang tampil di pojok kanan kartu
  final Color containerColor;
  final Color textColor;

  const CategoryStyle({
    required this.filterLabel,
    required this.badgeTitle,
    required this.containerColor,
    required this.textColor,
  });

  static CategoryStyle getStyle(OfferCategory category) {
    switch (category) {
      case OfferCategory.darurat:
        return const CategoryStyle(
          filterLabel: "Darurat",
          badgeTitle: "Darurat",
          containerColor: Color(0xffffdbd7),
          textColor: Color(0xff430002),
        );
      case OfferCategory.kelistrikan:
        return const CategoryStyle(
          filterLabel: "Kelistrikan",
          badgeTitle: "Kelistrikan",
          containerColor: Color(0xffffddb7),
          textColor: Color(0xff212435),
        );
      case OfferCategory.saluranAir:
        return const CategoryStyle(
          filterLabel: "Air",
          badgeTitle: "Saluran Air",
          containerColor: Color(0xffd0e8ff),
          textColor: Color(0xff003366),
        );
      case OfferCategory.atapDinding:
        return const CategoryStyle(
          filterLabel: "Atap & Dinding",
          badgeTitle: "Atap & Dinding",
          containerColor: Color(0xffb8f5d8),
          textColor: Color(0xff004d34),
        );
      case OfferCategory.kunciPintu:
        return const CategoryStyle(
          filterLabel: "Kunci & Pintu",
          badgeTitle: "Kunci & Pintu",
          containerColor: Color(0xffffd6d6),
          textColor: Color.fromARGB(255, 165, 135, 0),
        );
      case OfferCategory.teknologi:
        return const CategoryStyle(
          filterLabel: "Teknologi",
          badgeTitle: "Teknologi",
          containerColor: Color(0xff003366),
          textColor: Color.fromARGB(255, 254, 253, 253),
        );
      case OfferCategory.kendaraan:
        return const CategoryStyle(
          filterLabel: "Kendaraan",
          badgeTitle: "Kendaraan",
          containerColor: Color.fromARGB(255, 4, 4, 4),
          textColor: Color.fromARGB(255, 252, 252, 252),
        );
      case OfferCategory.angkutBarang:
        return const CategoryStyle(
          filterLabel: "Angkut Barang",
          badgeTitle: "Angkut Barang",
          containerColor: Color.fromARGB(255, 121, 0, 69),
          textColor: Color.fromARGB(255, 252, 252, 252),
        );
      case OfferCategory.bantuanLainnya:
        return const CategoryStyle(
          filterLabel: "Lainnya",
          badgeTitle: "Bantuan Lainnya",
          containerColor: Color.fromARGB(255, 71, 0, 177),
          textColor: Color.fromARGB(255, 254, 253, 253),
        );
    }
  }
}

// ============================================================================
// 3. MODEL DATA TAWARAN
// ============================================================================
class OfferItem {
  final String id;
  final OfferCategory category;
  final String distance;
  final DateTime?
  createdAt; // Khusus Darurat (dikonversi ke "5 detik yang lalu", dll)
  final String title;
  final String avatar;
  final String userName;
  final int wage;
  final String description;
  final String previewImage;
  final String addressDetail;
  final String offerId;

  OfferItem({
    required this.id,
    required this.category,
    required this.distance,
    this.createdAt,
    required this.title,
    required this.avatar,
    required this.userName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
    String? offerId,
  }) : offerId = offerId ?? id;
}

// ============================================================================
// 4. HALAMAN UTAMA (LIST TAWARAN PAGE)
// ============================================================================
class ListTawaranPage extends StatefulWidget {
  @override
  _ListTawaranPageState createState() => _ListTawaranPageState();
}

class _ListTawaranPageState extends State<ListTawaranPage> {
  // null berarti memilih filter "Semua Tawaran"
  OfferCategory? _selectedCategory;

  // Dummy Data untuk semua kategori
  final List<OfferItem> _allOffers = [];
  bool _isLoadingOffers = true;
  String? _offersError;
  double _latitude = -7.2575;
  double _longitude = 112.7521;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoadingOffers = true;
      _offersError = null;
    });
    try {
      try {
        final position = await Geolocator.getCurrentPosition();
        _latitude = position.latitude;
        _longitude = position.longitude;
      } catch (_) {}
      final offers = await AuthService.getNearbyOffers(
        latitude: _latitude,
        longitude: _longitude,
        limit: 50,
      );
      final items = <OfferItem>[];
      for (final offer in offers.where(
        (item) => '${item['status']}'.toUpperCase() == 'WAITING',
      )) {
        final item = await _offerFromJson(offer);
        items.add(item);
      }
      if (!mounted) return;
      setState(() {
        _allOffers
          ..clear()
          ..addAll(items);
        _isLoadingOffers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offersError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingOffers = false;
      });
    }
  }

  Future<OfferItem> _offerFromJson(Map<String, dynamic> offer) async {
    final category = Map<String, dynamic>.from(
      (offer['category_snapshot'] as Map?) ?? const {},
    );
    final label = '${category['label'] ?? category['name'] ?? 'Lainnya'}';
    final state = offer['is_sos'] == true
        ? OfferCategory.darurat
        : _categoryFromName(label);
    final requester = Map<String, dynamic>.from(
      (offer['requester_snapshot'] as Map?) ?? const {},
    );
    final budget = offer['agreed_price'] ?? offer['initial_budget'] ?? 0;
    final distance = offer['distance_m'];
    final created = DateTime.tryParse('${offer['created_at'] ?? ''}');
    final photos =
        (offer['photos'] as List?)?.cast<String>() ?? const <String>[];
    var image = photos.isEmpty ? 'assets/images/dummy.png' : photos.first;
    if (image != 'assets/images/dummy.png') {
      try {
        image = await AuthService.getMediaUrl(image);
      } catch (_) {}
    }
    return OfferItem(
      id: label,
      offerId: '${offer['_id']}',
      category: state,
      distance: distance is num
          ? (distance >= 1000
                ? '${(distance / 1000).toStringAsFixed(1)} KM'
                : '${distance.round()} Meter')
          : '',
      createdAt: created,
      title: '${offer['title'] ?? ''}',
      avatar: 'assets/logo/LogoBulat.png',
      userName: '${requester['name'] ?? 'Pengguna'}',
      wage: budget is num ? budget.toInt() : int.tryParse('$budget') ?? 0,
      description: '${offer['description'] ?? ''}',
      previewImage: image,
      addressDetail: '${offer['address_text'] ?? ''}',
    );
  }

  OfferCategory _categoryFromName(String name) {
    final value = name.toLowerCase();
    if (value.contains('listrik')) return OfferCategory.kelistrikan;
    if (value.contains('air')) return OfferCategory.saluranAir;
    if (value.contains('atap') || value.contains('dinding'))
      return OfferCategory.atapDinding;
    if (value.contains('kunci') || value.contains('pintu'))
      return OfferCategory.kunciPintu;
    if (value.contains('teknologi')) return OfferCategory.teknologi;
    if (value.contains('kendaraan')) return OfferCategory.kendaraan;
    if (value.contains('angkut')) return OfferCategory.angkutBarang;
    return OfferCategory.bantuanLainnya;
  }

  /* DUMMY_OFFERS
    OfferItem(
      id: '1',
      category: OfferCategory.darurat,
      distance: '180 M',
      createdAt: DateTime.now().subtract(Duration(seconds: 15)),
      title: 'Pipa Kamar Mandi Meletup',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Mas Amba',
      wage: 50000,
      description: 'Pipa kran patah dalam tembok, air menyembur deras. Butuh alat sok drat & seal tape.',
      addressDetail: 'Jl. Kalijudan Barat III No. 106',
    ),
    OfferItem(
      id: '2',
      category: OfferCategory.kelistrikan,
      distance: '320 meter',
      title: 'Stopkontak Kemasukan Cicak',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'User 1',
      wage: 60000,
      description: 'Perlu dicek sekring utama, kabel jalur ruang tamu bau gosong dan listrik sering jeglek.',
      addressDetail: 'Jl. Dharmahusada Indah Blok A',
    ),
    OfferItem(
      id: '3',
      category: OfferCategory.saluranAir,
      distance: '450 meter',
      title: 'Wastafel Dapur Mampet Total',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Bu Rina',
      wage: 45000,
      description: 'Air cucian piring tidak mau turun sama sekali, kemungkinan pipa pembuangan tersumbat lemak.',
      addressDetail: 'Gg. Pacar Kembang II No. 14',
    ),
    OfferItem(
      id: '4',
      category: OfferCategory.atapDinding,
      distance: '1.1 KM',
      title: 'Genteng Merosot & Bocor',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Pak Budi',
      wage: 85000,
      description: 'Ada 4 genteng bagian dapur yang geser habis hujan angin kemarin, perlu ditata dan ditambal.',
      addressDetail: 'Jl. Kertajaya Indah Timur',
    ),
    OfferItem(
      id: '5',
      category: OfferCategory.kunciPintu,
      distance: '600 meter',
      title: 'Kunci Kamar Kos Patah di Dalam',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Dimas',
      wage: 40000,
      description: 'Anak kunci patah separuh di dalam silinder pintu kamar, butuh dicabut atau ganti silinder baru.',
      addressDetail: 'Jl. Mulyorejo Tengah No. 22',
    ),
    OfferItem(
      id: '6',
      category: OfferCategory.teknologi,
      distance: '850 meter',
      title: 'Install Ulang & Bersihin Kipas Laptop',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Raka',
      wage: 100000,
      description: 'Laptop cepat panas waktu dipakai render, sekalian ganti thermal paste dan bersihin debu.',
      addressDetail: 'Jl. Gubeng Kertajaya V',
    ),
    OfferItem(
      id: '7',
      category: OfferCategory.kendaraan,
      distance: '250 meter',
      title: 'Jumper Aki Mobil Mati',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Pak Hendra',
      wage: 50000,
      description: 'Mobil tidak bisa starter karena lupa matikan lampu kabin semalaman, butuh bantuan kabel jumper.',
      addressDetail: 'Jl. Manyar Kertoarjo IV',
    ),
    OfferItem(
      id: '8',
      category: OfferCategory.angkutBarang,
      distance: '1.5 KM',
      title: 'Bantu Angkut Lemari & Kasur ke Lantai 2',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Siska',
      wage: 70000,
      description: 'Butuh tenaga bantu angkat lemari kayu 2 pintu dan springbed dari teras bawah ke kamar lantai 2.',
      addressDetail: 'Jl. Ploso Baru No. 45',
    ),
    OfferItem(
      id: '9',
      category: OfferCategory.bantuanLainnya,
      distance: '500 meter',
      title: 'Rakit Meja Belajar Knockdown',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Aldo',
      wage: 45000,
      description: 'Baru beli meja kerja masih di dalam kardus, butuh bantuan merakit dengan obeng.',
      addressDetail: 'Jl. Karang Menjangan No. 88',
    ),
  */

  // Menghitung jumlah item per kategori secara dinamis
  int _countByCategory(OfferCategory category) {
    return _allOffers.where((item) => item.category == category).length;
  }

  // Mengambil daftar tawaran sesuai tab kategori yang dipilih
  List<OfferItem> get _filteredOffers {
    if (_selectedCategory == null) {
      return _allOffers;
    }
    return _allOffers
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xfff7f4ff),
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(10, 60, 10, 0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // --------------------------------------------------------
                      // BAGIAN 1: FILTER KATEGORI (INTERAKTIF & RESPONSIF)
                      // --------------------------------------------------------
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                        padding: EdgeInsets.all(0),
                        width: MediaQuery.of(context).size.width,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              // Chip "Semua Tawaran"
                              _buildFilterChip(
                                label: "Semua Tawaran (${_allOffers.length})",
                                isSelected: _selectedCategory == null,
                                onTap: () {
                                  setState(() => _selectedCategory = null);
                                },
                              ),
                              // Chip untuk setiap kategori di OfferCategory
                              ...OfferCategory.values.map((category) {
                                final style = CategoryStyle.getStyle(category);
                                final count = _countByCategory(category);
                                return _buildFilterChip(
                                  label: "${style.filterLabel} ($count)",
                                  isSelected: _selectedCategory == category,
                                  onTap: () {
                                    setState(
                                      () => _selectedCategory = category,
                                    );
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),

                      // --------------------------------------------------------
                      // BAGIAN 2: LIST TAWARAN (MENGGUNAKAN REUSABLE WIDGET)
                      // --------------------------------------------------------
                      if (_isLoadingOffers)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        )
                      else if (_offersError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Text(_offersError!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: _loadOffers,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        )
                      else if (_filteredOffers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            "Belum ada tawaran untuk kategori ini.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._filteredOffers.map((offer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: TawaranCardWidget(
                              key: ValueKey(offer.id),
                              offerId: offer.offerId,
                              category: offer.category,
                              distance: offer.distance,
                              createdAt: offer.createdAt,
                              title: offer.title,
                              avatar: offer.avatar,
                              userName: offer.userName,
                              wage: offer.wage,
                              description: offer.description,
                              previewImage: offer.previewImage,
                              addressDetail: offer.addressDetail,
                            ),
                          );
                        }).toList(),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // --------------------------------------------------------
              // HEADER APPBAR
              // --------------------------------------------------------
              Container(
                margin: EdgeInsets.all(0),
                padding: EdgeInsets.all(0),
                width: MediaQuery.of(context).size.width,
                height: 60,
                decoration: BoxDecoration(color: Color(0xfff7f4ff)),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        color: Color(0xff212435),
                        iconSize: 24,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                        child: Text(
                          "List Tawaran",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget untuk Chip Filter Kategori
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.fromLTRB(0, 5, 0, 0),
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 15),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xff006b4a) : Color(0xffeceeff),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected
                  ? Color.fromARGB(255, 253, 253, 253)
                  : Color.fromARGB(255, 3, 3, 3),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. REUSABLE WIDGET: KARTU TAWARAN (TawaranCardWidget)
// Mendukung 2 tipe tampilan sekaligus:
// - Tipe 1: Kategori Darurat (Garis merah atas, jarak, konversi waktu, dll)
// - Tipe 2: Kategori Reguler (Kelistrikan, Air, Teknologi, dll dengan warna badge dinamis)
// ============================================================================
class TawaranCardWidget extends StatelessWidget {
  final String offerId;
  final OfferCategory category;
  final String distance;
  final DateTime? createdAt; // Digunakan pada kategori Darurat
  final String title;
  final String avatar;
  final String userName;
  final int wage;
  final String description;
  final String previewImage;
  final String addressDetail;

  const TawaranCardWidget({
    Key? key,
    required this.offerId,
    required this.category,
    required this.distance,
    this.createdAt,
    required this.title,
    required this.avatar,
    required this.userName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
  }) : super(key: key);

  // Fungsi konversi timestamp (DateTime) menjadi teks waktu relatif Bahasa Indonesia
  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return "Baru Saja";
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 5) {
      return "Baru Saja";
    } else if (diff.inSeconds < 60) {
      return "${diff.inSeconds} detik yang lalu";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} menit yang lalu";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} jam yang lalu";
    } else if (diff.inDays == 1) {
      return "Kemarin";
    } else {
      return "${diff.inDays} hari yang lalu";
    }
  }

  // Fungsi format angka integer ke Rupiah (contoh: 50000 -> Rp 50.000)
  String _formatRupiah(int amount, {bool withDotAfterRp = false}) {
    String str = amount.toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i != 0) {
        result = '.$result';
      }
    }
    return withDotAfterRp ? 'Rp. $result' : 'Rp $result';
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailTawaran(
          offerId: offerId,
          title: title,
          previewImage: previewImage,
          description: description,
          addressDetail: addressDetail,
          initialWage: wage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Membedakan layout Darurat dan Kategori Lainnya dalam satu widget
    if (category == OfferCategory.darurat) {
      return _buildDaruratCard(context);
    } else {
      return _buildRegularCategoryCard(context);
    }
  }

  // --------------------------------------------------------------------------
  // LAYOUT TIPE 1: KARTU DARURAT (Dengan garis merah di atas & waktu relatif)
  // --------------------------------------------------------------------------
  Widget _buildDaruratCard(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Garis merah penanda Darurat di atas container
          Container(
            width: MediaQuery.of(context).size.width,
            height: 5,
            decoration: BoxDecoration(
              color: Color(0xffba0011),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
            ),
          ),
          // Konten Utama Kartu Darurat
          Container(
            padding: EdgeInsets.all(10),
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Color(0xffffffff),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15.0),
                bottomRight: Radius.circular(15.0),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Baris Badge Darurat + Jarak & Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
                      decoration: BoxDecoration(
                        color: Color(0xffffdbd7),
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(0xffbe0011),
                            size: 10,
                          ),
                          Padding(
                            padding: EdgeInsets.all(5),
                            child: Text(
                              "Darurat - $distance",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: Color(0xff430002),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTimeAgo(createdAt),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        color: Color(0xffbd0011),
                      ),
                    ),
                  ],
                ),

                // Judul Tawaran
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xff000000),
                    ),
                  ),
                ),

                // Avatar & Nama Orang
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        height: 35,
                        width: 35,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Image.asset(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.person, size: 20),
                              ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 12,
                            color: Color(0xff39453d),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Kotak Upah & Deskripsi
                Container(
                  padding: EdgeInsets.all(10),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Color(0xffeceeff),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                        child: Text(
                          "Upah Tawaran",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xff3b4840),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 25),
                        child: Text(
                          _formatRupiah(wage),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xff006848),
                          ),
                        ),
                      ),
                      Text(
                        "Deskripsi: $description",
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 13,
                          color: Color(0xff131c2f),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Detail Tawaran
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MaterialButton(
                      onPressed: () => _navigateToDetail(context),
                      color: Color(0xff006b4a),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: EdgeInsets.all(16),
                      textColor: Color(0xfff8f8f8),
                      height: 40,
                      minWidth: 140,
                      child: Text(
                        "Detail Tawaran",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LAYOUT TIPE 2: KARTU KATEGORI REGULER (Kelistrikan, Air, Teknologi, dll)
  // --------------------------------------------------------------------------
  Widget _buildRegularCategoryCard(BuildContext context) {
    final CategoryStyle style = CategoryStyle.getStyle(category);

    return Container(
      padding: EdgeInsets.all(10),
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Color(0xffffffff),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Baris Atas: Avatar + Nama User + Jarak di Kiri & Badge Kategori di Kanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 35,
                    width: 35,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: Image.asset(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.person, size: 20),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xff000000),
                          ),
                        ),
                        Text(
                          distance,
                          style: TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 10,
                            color: Color(0xff3f4d44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Badge Kategori dengan Warna Dinamis sesuai KategoriLayananCard
              Container(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                decoration: BoxDecoration(
                  color: style.containerColor,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  style.badgeTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: style.textColor,
                  ),
                ),
              ),
            ],
          ),

          // Judul Tawaran
          Padding(
            padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xff000000),
              ),
            ),
          ),

          // Deskripsi Singkat (1 Baris dengan Ellipsis)
          Padding(
            padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
            child: Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Color(0xff000000),
              ),
            ),
          ),

          // Baris Bawah: Upah Tawaran & Tombol Detail Tawaran
          Padding(
            padding: EdgeInsets.fromLTRB(0, 15, 0, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Upah Tawaran",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Color(0xff404e46),
                      ),
                    ),
                    Text(
                      _formatRupiah(wage, withDotAfterRp: true),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xff006344),
                      ),
                    ),
                  ],
                ),
                MaterialButton(
                  onPressed: () => _navigateToDetail(context),
                  color: Color(0xff006848),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: EdgeInsets.all(16),
                  textColor: Color(0xffffffff),
                  height: 40,
                  minWidth: 140,
                  child: Text(
                    "Detail Tawaran",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
