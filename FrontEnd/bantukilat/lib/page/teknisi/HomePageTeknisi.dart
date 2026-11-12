import 'package:bantukilat/page/DetailTawaran.dart';
import 'package:bantukilat/page/teknisi/TugasSaya.dart';
import 'package:flutter/material.dart';

class HomePageTeknisi extends StatefulWidget {
  const HomePageTeknisi({super.key});

  @override
  State<HomePageTeknisi> createState() => _HomePageTeknisiState();
}

class _HomePageTeknisiState extends State<HomePageTeknisi> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 1. State Mode Siaga (Aktif / Mati)
  bool isSiagaAktif = true;

  // 2. State Kartu Darurat (Bisa di-slide 2 gambar & hilang saat klik Tolak)
  bool _showEmergencyCard = true;
  int _emergencySlideIndex = 0;

  final List<Map<String, dynamic>> _emergencySlides = [
    {"image": "assets/images/dummy.png", "label": "Foto Kerusakan"},
    {"image": "assets/images/dummy.png", "label": "Lokasi Peta"},
  ];

  // 3. Data Dummy Tawaran Sekitar (Dinamis, bisa ditolak/dihapus, tampil maks 3)
  final List<Map<String, dynamic>> _daftarTawaranSekitar = [
    {
      "id": 1,
      "namaUser": "User 123",
      "jarak": "320 Meter",
      "tipeKerusakan": "Kelistrikan",
      "warnaContainerTipe": const Color(0xffffddb8),
      "warnaTextTipe": const Color(0xff2c1800),
      "judulKerusakan": "Stopkontak bau gosong",
      "deskripsiKerusakan": "Perlu dicek sekring utama, kabel jalur ruang tamu bau menyengat dan sempat keluar percikan api.",
      "alamat": "Jl. Kalijudan Barat III No. 12, Surabaya",
      "upah": "Rp 35.000",
      "upahInt": 35000,
    },
    {
      "id": 2,
      "namaUser": "Pak Budi",
      "jarak": "450 Meter",
      "tipeKerusakan": "Saluran Air",
      "warnaContainerTipe": const Color(0xffd0e8ff),
      "warnaTextTipe": const Color(0xff003366),
      "judulKerusakan": "Wastafel Dapur Mampet",
      "deskripsiKerusakan": "Air pembuangan cucian piring tidak mau turun sama sekali sejak tadi pagi.",
      "alamat": "Jl. Mulyorejo Tengah No. 45, Surabaya",
      "upah": "Rp 40.000",
      "upahInt": 40000,
    },
    {
      "id": 3,
      "namaUser": "Bu Yan",
      "jarak": "500 Meter",
      "tipeKerusakan": "Lainnya",
      "warnaContainerTipe": const Color(0xffe2d4ff),
      "warnaTextTipe": const Color(0xff3a0066),
      "judulKerusakan": "Engsel Pintu Pagar Lepas",
      "deskripsiKerusakan": "Las engsel bawah pagar besi patah, pintu pagar miring tidak bisa ditutup.",
      "alamat": "Jl. Pacar Kembang II No. 8, Surabaya",
      "upah": "Rp 50.000",
      "upahInt": 50000,
    },
  ];

  // Widget Sidebar (Overlay Drawer)
  Widget _buildSidebar(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      width: 200,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: const Color(0xff006a49),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0x4d9e9e9e), width: 1),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 30, 5, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                height: 60,
                width: 60,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Image.asset(
                  "assets/logo/LogoBulat.png",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, color: Colors.grey),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 5, 0, 15),
                child: Text(
                  "Teknisi",
                  textAlign: TextAlign.start,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.normal,
                    fontSize: 18,
                    color: Color(0xffffffff),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                width: MediaQuery.of(context).size.width,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Profil",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Obrolan",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "List Tawaran",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TugasSaya()),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tugas",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Pengaturan",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Tentang Aplikasi",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xffffffff),
                        size: 24,
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

  @override
  Widget build(BuildContext context) {
    // Ambil maksimal 3 tawaran yang ditampilkan di halaman utama
    final List<Map<String, dynamic>> displayedOffers = _daftarTawaranSekitar
        .take(3)
        .toList();
    final int waitingCount = displayedOffers.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xfff8f5ff),
      drawer: _buildSidebar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // ==========================================================
                // HEADER DENGAN SWITCH MODE SIAGA (AKTIF = HIJAU, MATI = MERAH)
                // ==========================================================
                Container(
                  padding: const EdgeInsets.all(10),
                  width: MediaQuery.of(context).size.width,
                  height: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () {
                                _scaffoldKey.currentState?.openDrawer();
                              },
                              child: const Icon(
                                Icons.menu,
                                color: Color(0xff141c30),
                                size: 24,
                              ),
                            ),
                          ),
                          // Badge Status Mode Siaga (Responsif Hijau / Merah Error)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSiagaAktif
                                  ? const Color(0xff88ffc9)
                                  : const Color(0xffffdad5),
                              borderRadius: BorderRadius.circular(15.0),
                              border: Border.all(
                                color: isSiagaAktif
                                    ? const Color(0xff006848)
                                          .withValues(alpha: 0.3)
                                    : const Color(0xffba0011)
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSiagaAktif
                                      ? Icons.circle
                                      : Icons.error_outline,
                                  color: isSiagaAktif
                                      ? const Color(0xff006848)
                                      : const Color(0xffba0011),
                                  size: isSiagaAktif ? 10 : 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isSiagaAktif
                                      ? "Mode Siaga Aktif"
                                      : "Mode Siaga Nonaktif",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: isSiagaAktif
                                        ? const Color(0xff006b4a)
                                        : const Color(0xff93000a),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Switch(
                            value: isSiagaAktif,
                            onChanged: (value) {
                              setState(() {
                                isSiagaAktif = value;
                              });
                            },
                            activeThumbColor: const Color(0xffffffff),
                            activeTrackColor: const Color(0xff006243),
                            inactiveThumbColor: const Color(0xffffffff),
                            inactiveTrackColor: const Color(0xffba0011),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.notifications,
                          color: Color(0xff141c2f),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // Banner Peringatan Merah saat Mode Siaga dimatikan
                if (!isSiagaAktif)
                  Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffffdad5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffba0011)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xffba0011),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Mode Siaga sedang mati! Anda tidak akan menerima panggilan darurat baru di sekitar Anda.",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff93000a),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 5),

                // ==========================================================
                // KARTU DARURAT UTAMA (DENGAN SLIDER 2 GAMBAR & TOMBOL TOLAK)
                // ==========================================================
                if (_showEmergencyCard)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xffff0000),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10.0),
                              topRight: Radius.circular(10.0),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(15),
                          width: MediaQuery.of(context).size.width,
                          decoration: const BoxDecoration(
                            color: Color(0xffffffff),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12.0),
                              bottomRight: Radius.circular(12.0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffcd6d2),
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    child: const Row(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: Icon(
                                            Icons.circle,
                                            color: Color(0xffbe0011),
                                            size: 10,
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5,
                                          ),
                                          child: Text(
                                            "Darurat - 180 M",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              color: Color(0xffba0011),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xffe2e7ff),
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: const Text(
                                      "Baru Saja",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Kran Pipa Jebol & Air Meluap",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xff000000),
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Color(0xffe02928),
                                      size: 15,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Ibu Ratna",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // SLIDER 2 GAMBAR (FOTO KERUSAKAN & PETA)
                              SizedBox(
                                height: 130,
                                width: MediaQuery.of(context).size.width,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: PageView.builder(
                                    itemCount: _emergencySlides.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _emergencySlideIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(
                                            _emergencySlides[index]["image"]!,
                                            height: 130,
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    height: 130,
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                },
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    index == 0
                                                        ? Icons.photo_camera
                                                        : Icons.map,
                                                    color: Colors.white,
                                                    size: 11,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _emergencySlides[index]["label"]!,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Indikator Dots Slider
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _emergencySlides.length,
                                    (index) {
                                      final bool isActive =
                                          _emergencySlideIndex == index;
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        margin: EdgeInsets.only(
                                          left: index == 0 ? 0 : 5,
                                        ),
                                        width: isActive ? 14 : 10,
                                        height: isActive ? 14 : 10,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xff006948)
                                              : const Color(0xfff7f4ff),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0x4d9e9e9e),
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const Padding(
                                padding: EdgeInsets.only(bottom: 5),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Lokasi: RT 02 No. 14, Depan Pos Ronda",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                      color: Color(0xff000000),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0x65ffddb9),
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 5),
                                          child: Text(
                                            "Tawaran Upah",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              color: Color(0xff845200),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "Rp 55.000",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xff000000),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // TOMBOL TOLAK (Menghilangkan Container Darurat)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          _showEmergencyCard = false;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Tawaran darurat Ibu Ratna telah ditolak.",
                                            ),
                                            backgroundColor: Colors.redAccent,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 110,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffe52a28),
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          "Tolak",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xffffffff),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // TOMBOL DETAIL TAWARAN
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DetailTawaran(
                                                  title: "Kran Pipa Jebol & Air Meluap",
                                                  customerName: "Ibu Ratna",
                                                  previewImage:
                                                      "assets/images/dummy.png",
                                                  description: "Kran patah di drat tembok, air meluap ke kamar tidur! Butuh bantuan segera sebelum banjir ke kasur.",
                                                  mapImage:
                                                      "assets/images/dummy.png",
                                                  addressDetail: "RT 02 No. 14, Depan Pos Ronda",
                                                  initialWage: 55000,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 110,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xff006546),
                                          borderRadius: BorderRadius.circular(
                                            10.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          "Detail Tawaran",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xffffffff),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ==========================================================
                // JUDUL TAWARAN SEKITAR (JUMLAH MENUNGGU RESPONSIF MAKS 3)
                // ==========================================================
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tawaran Sekitar",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xff000000),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: waitingCount > 0
                              ? const Color(0xff86fac5)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: waitingCount > 0
                                    ? const Color(0xff006646)
                                    : Colors.grey.shade700,
                                size: 9,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "$waitingCount Menunggu",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: waitingCount > 0
                                      ? const Color(0xff006646)
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================================
                // LIST TAWARAN SEKITAR DINAMIS (MAKSIMAL 3 ITEM)
                // ==========================================================
                if (displayedOffers.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(24),
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Tidak ada tawaran menunggu di sekitar Anda.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff3d4a42),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Reset ulang dummy untuk keperluan demo ke juri
                            setState(() {
                              _showEmergencyCard = true;
                            });
                          },
                          child: const Text("Muat Ulang Data Demo"),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayedOffers.map((item) {
                    return TawaranUserCard(
                      namaUser: item["namaUser"],
                      jarak: item["jarak"],
                      tipeKerusakan: item["tipeKerusakan"],
                      warnaContainerTipe: item["warnaContainerTipe"],
                      warnaTextTipe: item["warnaTextTipe"],
                      judulKerusakan: item["judulKerusakan"],
                      deskripsiKerusakan: item["deskripsiKerusakan"],
                      upah: item["upah"],
                      onTolakTap: () {
                        setState(() {
                          _daftarTawaranSekitar.removeWhere(
                            (el) => el["id"] == item["id"],
                          );
                        });
                      },
                      onDetailTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailTawaran(
                              title: item["judulKerusakan"],
                              customerName: item["namaUser"],
                              previewImage: "assets/images/dummy.png",
                              description: item["deskripsiKerusakan"],
                              mapImage: "assets/images/dummy.png",
                              addressDetail: item["alamat"],
                              initialWage: item["upahInt"],
                            ),
                          ),
                        );
                      },
                    );
                  }),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Align(
                    alignment: Alignment.center,
                    child: MaterialButton(
                      onPressed: () {},
                      color: const Color(0xff006646),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.all(16),
                      textColor: const Color(0xffffffff),
                      height: 50,
                      minWidth: 140,
                      child: const Text(
                        "Lihat Tawaran Lainnya",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// CUSTOM WIDGET: TawaranUserCard
// =========================================================================
class TawaranUserCard extends StatelessWidget {
  final String namaUser;
  final String jarak;
  final String tipeKerusakan;
  final Color warnaContainerTipe;
  final Color warnaTextTipe;
  final String judulKerusakan;
  final String deskripsiKerusakan;
  final String upah;
  final String imagePath;
  final VoidCallback? onDetailTap;
  final VoidCallback? onTolakTap;

  const TawaranUserCard({
    super.key,
    required this.namaUser,
    required this.jarak,
    required this.tipeKerusakan,
    required this.warnaContainerTipe,
    this.warnaTextTipe = const Color(0xff2c1800),
    required this.judulKerusakan,
    required this.deskripsiKerusakan,
    required this.upah,
    this.imagePath = "assets/logo/LogoBulat.png",
    this.onDetailTap,
    this.onTolakTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(15),
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    margin: const EdgeInsets.only(right: 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaUser,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xff000000),
                        ),
                      ),
                      Text(
                        jarak,
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: Color(0xff3c4941),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                decoration: BoxDecoration(
                  color: warnaContainerTipe,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  tipeKerusakan,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: warnaTextTipe,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              judulKerusakan,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xff000000),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              deskripsiKerusakan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Color(0xff3d4a42),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Upah Tawaran",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: Color(0xff3e4c44),
                    ),
                  ),
                  Text(
                    upah,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xff006b4a),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onTolakTap != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onTolakTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xffffdad5),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "Tolak",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xffba0011),
                            ),
                          ),
                        ),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onDetailTap,
                    child: Container(
                      width: 110,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xff006445),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Detail Tawaran",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xffffffff),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
