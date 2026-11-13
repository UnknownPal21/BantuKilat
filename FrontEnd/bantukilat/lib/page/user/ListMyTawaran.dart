import 'package:bantukilat/page/DetailTawaran.dart';
import 'package:flutter/material.dart';

// ============================================================================
// 1. DEFINISI STATUS TAWARAN SAYA (ENUM)
// ============================================================================
enum MyOfferStatus { pengerjaan, menunggu, selesai }

// ============================================================================
// 2. DEFINISI KATEGORI KERUSAKAN & KONFIGURASI WARNANYA
// Menyesuaikan daftar KategoriLayananCard (judul, warna container, warna teks)
// ============================================================================
enum DamageCategory {
  kelistrikan,
  saluranAir,
  atapDinding,
  kunciPintu,
  teknologi,
  kendaraan,
  angkutBarang,
  bantuanLainnya,
}

class DamageCategoryStyle {
  final String title;
  final Color containerColor;
  final Color textColor;

  const DamageCategoryStyle({
    required this.title,
    required this.containerColor,
    required this.textColor,
  });

  static DamageCategoryStyle getStyle(DamageCategory category) {
    switch (category) {
      case DamageCategory.kelistrikan:
        return const DamageCategoryStyle(
          title: "Kelistrikan",
          containerColor: Color(0xffffddb7),
          textColor: Color(0xff212435),
        );
      case DamageCategory.saluranAir:
        return const DamageCategoryStyle(
          title: "Saluran Air",
          containerColor: Color(0xffd0e8ff),
          textColor: Color(0xff003366),
        );
      case DamageCategory.atapDinding:
        return const DamageCategoryStyle(
          title: "Atap & Dinding",
          containerColor: Color(0xffb8f5d8),
          textColor: Color(0xff004d34),
        );
      case DamageCategory.kunciPintu:
        return const DamageCategoryStyle(
          title: "Kunci & Pintu",
          containerColor: Color(0xffffd6d6),
          textColor: Color.fromARGB(255, 165, 135, 0),
        );
      case DamageCategory.teknologi:
        return const DamageCategoryStyle(
          title: "Teknologi",
          containerColor: Color(0xff003366),
          textColor: Color.fromARGB(255, 254, 253, 253),
        );
      case DamageCategory.kendaraan:
        return const DamageCategoryStyle(
          title: "Kendaraan",
          containerColor: Color.fromARGB(255, 4, 4, 4),
          textColor: Color.fromARGB(255, 252, 252, 252),
        );
      case DamageCategory.angkutBarang:
        return const DamageCategoryStyle(
          title: "Angkut Barang",
          containerColor: Color.fromARGB(255, 121, 0, 69),
          textColor: Color.fromARGB(255, 252, 252, 252),
        );
      case DamageCategory.bantuanLainnya:
        return const DamageCategoryStyle(
          title: "Bantuan Lainnya",
          containerColor: Color.fromARGB(255, 71, 0, 177),
          textColor: Color.fromARGB(255, 254, 253, 253),
        );
    }
  }
}

// ============================================================================
// 3. MODEL DATA TAWARAN SAYA
// ============================================================================
class MyOfferItem {
  final String id;
  final MyOfferStatus status;
  final DamageCategory damageCategory;
  final String title;
  final String avatar;
  final String userName;
  final int wage;
  final String description;
  final String previewImage;
  final String addressDetail;

  MyOfferItem({
    required this.id,
    required this.status,
    required this.damageCategory,
    required this.title,
    required this.avatar,
    required this.userName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
  });
}

// ============================================================================
// 4. HALAMAN UTAMA (LIST MY TAWARAN)
// ============================================================================
class ListMyTawaran extends StatefulWidget {
  @override
  _ListMyTawaranState createState() => _ListMyTawaranState();
}

class _ListMyTawaranState extends State<ListMyTawaran> {
  // null berarti memilih filter "Semua"
  MyOfferStatus? _selectedFilter;

  // Dummy Data Tawaran Saya
  final List<MyOfferItem> _myOffers = [
    MyOfferItem(
      id: '1',
      status: MyOfferStatus.pengerjaan,
      damageCategory: DamageCategory.saluranAir,
      title: 'Pipa Kamar Mandi Meletup',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 50000,
      description: 'Pipa kran patah dalam tembok, air menyembur deras. Butuh alat sok drat & seal tape.',
      addressDetail: 'Jl. Kalijudan Barat III No. 106',
    ),
    MyOfferItem(
      id: '2',
      status: MyOfferStatus.menunggu,
      damageCategory: DamageCategory.kelistrikan,
      title: 'Stopkontak Kamar Kos Meleleh',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 60000,
      description: 'Colokan listrik dekat meja belajar gosong waktu dipakai colok setrika, butuh ganti saklar tanam baru.',
      addressDetail: 'Jl. Mulyorejo Tengah No. 22',
    ),
    MyOfferItem(
      id: '3',
      status: MyOfferStatus.menunggu,
      damageCategory: DamageCategory.teknologi,
      title: 'Bersihin Fan Laptop & Ganti Thermal Paste',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 85000,
      description: 'Laptop sering overheat saat dipakai ngoding dan render video, butuh dibersihkan bagian kipas dalamnya.',
      addressDetail: 'Jl. Mulyorejo Tengah No. 22',
    ),
    MyOfferItem(
      id: '4',
      status: MyOfferStatus.selesai,
      damageCategory: DamageCategory.kunciPintu,
      title: 'Ganti Silinder Kunci Pintu Kamar',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 45000,
      description: 'Kunci pintu macet susah diputar dari luar, silinder kunci baru sudah disiapkan tinggal pasang.',
      addressDetail: 'Jl. Dharmahusada Indah Blok A',
    ),
    MyOfferItem(
      id: '5',
      status: MyOfferStatus.selesai,
      damageCategory: DamageCategory.atapDinding,
      title: 'Tambal Plafon Rembes Air Hujan',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 90000,
      description: 'Ada retakan di sambungan genteng atas kamar yang bikin plafon netes kalau hujan deras.',
      addressDetail: 'Jl. Kertajaya Indah Timur',
    ),
    MyOfferItem(
      id: '6',
      status: MyOfferStatus.selesai,
      damageCategory: DamageCategory.angkutBarang,
      title: 'Bantu Pindahan Barang ke Apartemen',
      avatar: 'assets/logo/LogoBulat.png',
      userName: 'Saya',
      wage: 100000,
      description: 'Bantu angkat kardus buku, monitor PC, dan meja lipat dari lantai bawah ke kamar.',
      addressDetail: 'Jl. Manyar Kertoarjo IV',
    ),
  ];

  // Menghitung jumlah tawaran berdasarkan status secara responsif
  int _countByStatus(MyOfferStatus status) {
    return _myOffers.where((item) => item.status == status).length;
  }

  // Menyaring daftar tawaran sesuai tombol filter yang aktif
  List<MyOfferItem> get _filteredOffers {
    if (_selectedFilter == null) {
      return _myOffers;
    }
    return _myOffers.where((item) => item.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final int countPengerjaan = _countByStatus(MyOfferStatus.pengerjaan);
    final int countMenunggu = _countByStatus(MyOfferStatus.menunggu);
    final int countSelesai = _countByStatus(MyOfferStatus.selesai);

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
                      // BAGIAN 1: CONTAINER RINGKASAN 3 KATEGORI (RESPONSIF)
                      // --------------------------------------------------------
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                        padding: EdgeInsets.all(10),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          color: Color(0xffffffff),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                _buildSummaryBox(
                                  count: countPengerjaan,
                                  label: "PENGERJAAN",
                                  bgColor: Color(0xffffdcd8),
                                  textColor: Color(0xffba1a1a),
                                  rightPadding: 10,
                                ),
                                _buildSummaryBox(
                                  count: countMenunggu,
                                  label: "MENUNGGU",
                                  bgColor: Color(0xFFF2F3FF),
                                  textColor: Color.fromARGB(255, 6, 6, 6),
                                  rightPadding: 10,
                                ),
                                _buildSummaryBox(
                                  count: countSelesai,
                                  label: "SELESAI",
                                  bgColor: Color(0xffb8f5d8),
                                  textColor: Color(0xFF005137),
                                  rightPadding: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --------------------------------------------------------
                      // BAGIAN 2: ROW FILTER (SEMUA, PENGERJAAN, MENUNGGU, SELESAI)
                      // --------------------------------------------------------
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 5, 0, 15),
                        padding: EdgeInsets.all(0),
                        width: MediaQuery.of(context).size.width,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              _buildFilterTab(
                                label: "Semua (${_myOffers.length})",
                                isSelected: _selectedFilter == null,
                                onTap: () {
                                  setState(() => _selectedFilter = null);
                                },
                              ),
                              _buildFilterTab(
                                label: "Pengerjaan ($countPengerjaan)",
                                isSelected:
                                    _selectedFilter == MyOfferStatus.pengerjaan,
                                onTap: () {
                                  setState(
                                    () => _selectedFilter =
                                        MyOfferStatus.pengerjaan,
                                  );
                                },
                              ),
                              _buildFilterTab(
                                label: "Menunggu ($countMenunggu)",
                                isSelected:
                                    _selectedFilter == MyOfferStatus.menunggu,
                                onTap: () {
                                  setState(
                                    () => _selectedFilter =
                                        MyOfferStatus.menunggu,
                                  );
                                },
                              ),
                              _buildFilterTab(
                                label: "Selesai ($countSelesai)",
                                isSelected:
                                    _selectedFilter == MyOfferStatus.selesai,
                                onTap: () {
                                  setState(
                                    () =>
                                        _selectedFilter = MyOfferStatus.selesai,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --------------------------------------------------------
                      // BAGIAN 3: DAFTAR KARTU TAWARAN SAYA (REUSABLE WIDGET)
                      // --------------------------------------------------------
                      if (_filteredOffers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            "Tidak ada tawaran pada status ini.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._filteredOffers.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: MyTawaranCardWidget(
                              key: ValueKey(item.id),
                              status: item.status,
                              damageCategory: item.damageCategory,
                              title: item.title,
                              avatar: item.avatar,
                              userName: item.userName,
                              wage: item.wage,
                              description: item.description,
                              previewImage: item.previewImage,
                              addressDetail: item.addressDetail,
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
                          "Tawaran Saya",
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

  // Helper Widget untuk Kotak Statistik di Atas
  Widget _buildSummaryBox({
    required int count,
    required String label,
    required Color bgColor,
    required Color textColor,
    required double rightPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, rightPadding, 0),
      child: Container(
        width: 100,
        height: 57,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Color(0xff3f4c44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget untuk Tombol Filter Kategori Status
  Widget _buildFilterTab({
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
            color: isSelected ? Color(0xff006b4a) : Color(0xffebeeff),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected
                  ? Color.fromARGB(255, 253, 253, 253)
                  : Color(0xff000000),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. REUSABLE WIDGET: KARTU TAWARAN SAYA (MyTawaranCardWidget)
// Dipanggil menggunakan parameter required this
// ============================================================================
class MyTawaranCardWidget extends StatelessWidget {
  final MyOfferStatus status;
  final DamageCategory damageCategory;
  final String title;
  final String avatar;
  final String userName;
  final int wage;
  final String description;
  final String previewImage;
  final String addressDetail;

  const MyTawaranCardWidget({
    Key? key,
    required this.status,
    required this.damageCategory,
    required this.title,
    required this.avatar,
    required this.userName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
  }) : super(key: key);

  // Format angka integer ke Rupiah (contoh: 50000 -> Rp 50.000)
  String _formatRupiah(int amount) {
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
    return 'Rp $result';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Konfigurasi warna garis atas & badge berdasarkan status (Pengerjaan, Menunggu, Selesai)
    Color topBarColor;
    Color statusBadgeBgColor;
    Color statusDotColor;
    Color statusTextColor;
    String statusText;

    switch (status) {
      case MyOfferStatus.pengerjaan:
        topBarColor = Color(0xffba0011); // Garis merah untuk Pengerjaan
        statusBadgeBgColor = Color(0xffffdbd7);
        statusDotColor = Color(0xffbe0011);
        statusTextColor = Color(0xff430002);
        statusText = "PENGERJAAN";
        break;
      case MyOfferStatus.menunggu:
        topBarColor = Color(0xFF9EA5D9); // Garis selaras tema Menunggu (F2F3FF)
        statusBadgeBgColor = Color(0xFFF2F3FF);
        statusDotColor = Color(0xff3f4c44);
        statusTextColor = Color.fromARGB(255, 6, 6, 6);
        statusText = "MENUNGGU";
        break;
      case MyOfferStatus.selesai:
        topBarColor = Color(0xff006b4a); // Garis hijau untuk Selesai
        statusBadgeBgColor = Color(0xffb8f5d8);
        statusDotColor = Color(0xFF005137);
        statusTextColor = Color(0xFF005137);
        statusText = "SELESAI";
        break;
    }

    // 2. Mengambil konfigurasi nama & warna badge kategori kerusakan
    final DamageCategoryStyle damageStyle = DamageCategoryStyle.getStyle(
      damageCategory,
    );

    return Container(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Garis Penanda Status di Atas Container
          Container(
            width: MediaQuery.of(context).size.width,
            height: 5,
            decoration: BoxDecoration(
              color: topBarColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
            ),
          ),

          // Konten Utama Kartu
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
                // Baris Atas: Badge Status di Kiri & Badge Kategori Kerusakan di Kanan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge Status (Pengerjaan / Menunggu / Selesai)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 0, horizontal: 6),
                      decoration: BoxDecoration(
                        color: statusBadgeBgColor,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: statusDotColor, size: 10),
                          Padding(
                            padding: EdgeInsets.all(5),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: statusTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge Kategori Kerusakan (Sesuai warna KategoriLayananCard)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: damageStyle.containerColor,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Text(
                        damageStyle.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: damageStyle.textColor,
                        ),
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

                // Avatar & Nama User ("Saya")
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

                // Tombol Detail
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MaterialButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailTawaran(
                              title: title,
                              previewImage: previewImage,
                              description: description,
                              addressDetail: addressDetail,
                              initialWage: wage,
                            ),
                          ),
                        );
                      },
                      color: Color(0xff006b4a),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      padding: EdgeInsets.all(16),
                      textColor: Color(0xfff8f8f8),
                      height: 40,
                      minWidth: 140,
                      child: Text(
                        "Detail",
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
}
