import 'dart:convert';

import 'package:bantukilat/page/DetailTawaran.dart';
import 'package:bantukilat/page/teknisi/ListTawaranPage.dart';
import 'package:bantukilat/page/teknisi/TugasSaya.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:bantukilat/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bantukilat/page/loginpage.dart';

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
  bool _showEmergencyCard = false;
  int _emergencySlideIndex = 0;

  // Alamat di Kartu Darurat yang digunakan bersama oleh teks, slide peta ke-2, dan halaman DetailTawaran
  final String _emergencyAddress = "RT 02 No. 14, Depan Pos Ronda";
  final MapController _emergencyMapController = MapController();
  LatLng _emergencyLocation = const LatLng(-7.2575, 112.7521);
  bool _isSearchingEmergencyMap = true;

  final List<Map<String, dynamic>> _emergencySlides = [
    {"image": "assets/images/dummy.png", "label": "Foto Kerusakan"},
    {"image": "assets/images/dummy.png", "label": "Lokasi Peta"},
  ];

  // 3. Data Dummy Tawaran Sekitar (Dinamis, bisa ditolak/dihapus, tampil maks 3)
  final List<Map<String, dynamic>> _daftarTawaranSekitar = [];
  Map<String, dynamic>? _technicianProfile;
  double? _technicianLat;
  double? _technicianLng;
  bool _isLoadingNearby = true;
  String? _nearbyError;

  Future<void> _loadTechnicianData() async {
    final profile = await AuthService.getCurrentUser();
    if (mounted) setState(() => _technicianProfile = profile);
    await _loadNearbyOffers();
  }

  Future<void> _loadNearbyOffers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNearby = true;
      _nearbyError = null;
    });
    try {
      double lat = _technicianLat ?? -7.2575;
      double lng = _technicianLng ?? 112.7521;
      try {
        final position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
        _technicianLat = lat;
        _technicianLng = lng;
      } catch (_) {}
      final offers = await AuthService.getNearbyOffers(
        latitude: lat,
        longitude: lng,
        limit: 20,
      );
      final items = offers
          .where((offer) => '${offer['status']}'.toUpperCase() == 'WAITING')
          .map(_offerToHomeCard)
          .toList();
      if (!mounted) return;
      setState(() {
        _daftarTawaranSekitar
          ..clear()
          ..addAll(items);
        _isLoadingNearby = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingNearby = false;
      });
    }
  }

  Map<String, dynamic> _offerToHomeCard(Map<String, dynamic> offer) {
    final category = Map<String, dynamic>.from(
      (offer['category_snapshot'] as Map?) ?? const {},
    );
    final categoryName = '${category['label'] ?? 'Layanan'}';
    final palette = _categoryPalette(categoryName);
    final requester = Map<String, dynamic>.from(
      (offer['requester_snapshot'] as Map?) ?? const {},
    );
    final budget = offer['agreed_price'] ?? offer['initial_budget'] ?? 0;
    final distance = offer['distance_m'];
    return {
      'id': '${offer['_id']}',
      'offer': offer,
      'namaUser': '${requester['name'] ?? 'Pengguna'}',
      'jarak': distance is num
          ? (distance >= 1000
                ? '${(distance / 1000).toStringAsFixed(1)} KM'
                : '${distance.round()} Meter')
          : '',
      'tipeKerusakan': categoryName,
      'warnaContainerTipe': palette.$1,
      'warnaTextTipe': palette.$2,
      'judulKerusakan': '${offer['title'] ?? ''}',
      'deskripsiKerusakan': '${offer['description'] ?? ''}',
      'alamat': '${offer['address_text'] ?? ''}',
      'upahInt': budget is num ? budget.toInt() : int.tryParse('$budget') ?? 0,
      'upah': _formatOfferPrice(budget),
    };
  }

  (Color, Color) _categoryPalette(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('air'))
      return (const Color(0xffd0e8ff), const Color(0xff003366));
    if (lower.contains('listrik'))
      return (const Color(0xffffddb8), const Color(0xff2c1800));
    if (lower.contains('darurat'))
      return (const Color(0xffffdbd7), const Color(0xff430002));
    return (const Color(0xffe2d4ff), const Color(0xff3a0066));
  }

  String _formatOfferPrice(dynamic amount) {
    final value = amount is num ? amount.toInt() : int.tryParse('$amount') ?? 0;
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _logoutTechnician() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _openTechnicianOffer(Map<String, dynamic> offer) async {
    final id = '${offer['_id'] ?? ''}';
    final detail = await AuthService.getOffer(id);
    if (!mounted) return;
    final photos =
        (detail['photos'] as List?)?.cast<String>() ?? const <String>[];
    String image = 'assets/images/dummy.png';
    if (photos.isNotEmpty) {
      try {
        image = await AuthService.getMediaUrl(photos.first);
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailTawaran(
          offerId: id,
          title: '${detail['title'] ?? ''}',
          customerName:
              '${(detail['requester_snapshot'] as Map?)?['name'] ?? 'Pengguna'}',
          previewImage: image,
          description: '${detail['description'] ?? ''}',
          addressDetail: '${detail['address_text'] ?? ''}',
          initialWage: (detail['initial_budget'] as num?)?.toInt() ?? 0,
        ),
      ),
    );
    _loadNearbyOffers();
  }

  @override
  void initState() {
    super.initState();
    _geocodeEmergencyAddress();
    _loadTechnicianData();
  }

  // Melacak lokasi peta untuk slide ke-2 pada Kartu Darurat berdasarkan _emergencyAddress
  Future<void> _geocodeEmergencyAddress() async {
    final String raw = _emergencyAddress.trim();
    if (raw.isEmpty) {
      if (mounted) setState(() => _isSearchingEmergencyMap = false);
      return;
    }

    final List<String> candidates = [];
    void addUnique(String q) {
      final clean = q.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isNotEmpty && !candidates.contains(clean)) {
        candidates.add(clean);
      }
    }

    String expanded = raw
        .replaceAll(RegExp(r'\bJl\.?\s*', caseSensitive: false), 'Jalan ')
        .replaceAll(RegExp(r'\bGg\.?\s*', caseSensitive: false), 'Gang ');
    String withoutNumbers = expanded
        .replaceAll(
          RegExp(r'\bNo\.?\s*\d+[a-zA-Z]?\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\bRT\.?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRW\.?\s*\d+\b', caseSensitive: false), '');
    String withoutRoman = withoutNumbers.replaceAll(
      RegExp(r'\s+\b(I|II|III|IV|V|VI|VII|VIII|IX|X|\d+)\b(?=\s*,|$)'),
      '',
    );

    addUnique(expanded);
    addUnique(withoutNumbers);
    addUnique(withoutRoman);
    if (raw.contains(',')) {
      addUnique(raw.split(',').last.trim());
    }
    addUnique(raw);

    try {
      LatLng? found;
      for (final q in candidates) {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=1&countrycodes=id',
        );
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'BantuKilatApp/1.0 (flutter_map)'},
        );
        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          if (data.isNotEmpty) {
            found = LatLng(
              double.parse(data[0]['lat']),
              double.parse(data[0]['lon']),
            );
            break;
          }
        }
      }

      if (found != null && mounted) {
        setState(() {
          _emergencyLocation = found!;
          _isSearchingEmergencyMap = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _emergencyMapController.move(_emergencyLocation, 15.5);
          } catch (_) {}
        });
      } else {
        if (mounted) setState(() => _isSearchingEmergencyMap = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingEmergencyMap = false);
    }
  }

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
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 5, 0, 15),
                child: Text(
                  _technicianProfile?['name'] as String? ?? "Teknisi",
                  textAlign: TextAlign.start,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListTawaranPage()),
                ),
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
                onTap: _logoutTechnician,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Log Out",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xffffffff),
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 24),
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

                              // SLIDER 2 ITEM (SLIDE 1: FOTO KERUSAKAN, SLIDE 2: PETA LOKASI ASLI)
                              SizedBox(
                                height: 200,
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
                                          if (index == 0)
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
                                            )
                                          else
                                            // Slide ke-2: Maps otomatis sesuai alamat di container darurat
                                            IgnorePointer(
                                              child: FlutterMap(
                                                mapController:
                                                    _emergencyMapController,
                                                options: MapOptions(
                                                  initialCenter:
                                                      _emergencyLocation,
                                                  initialZoom: 15.5,
                                                ),
                                                children: [
                                                  TileLayer(
                                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                    userAgentPackageName:
                                                        'com.bantukilat.app',
                                                  ),
                                                  MarkerLayer(
                                                    markers: [
                                                      Marker(
                                                        point:
                                                            _emergencyLocation,
                                                        width: 44,
                                                        height: 44,
                                                        alignment:
                                                            Alignment.topCenter,
                                                        child: const Icon(
                                                          Icons.location_on,
                                                          color: Color(
                                                            0xffe52a28,
                                                          ),
                                                          size: 34,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (index == 1 &&
                                              _isSearchingEmergencyMap)
                                            Container(
                                              color: Colors.black12,
                                              alignment: Alignment.center,
                                              child: const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xff006a49),
                                                    ),
                                              ),
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

                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Lokasi: $_emergencyAddress",
                                    style: const TextStyle(
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
                                      horizontal: 15,
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
                                      MainAxisAlignment.spaceEvenly,
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
                                        width: 130,
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
                                            builder: (context) => DetailTawaran(
                                              title: "Kran Pipa Jebol & Air Meluap",
                                              customerName: "Ibu Ratna",
                                              previewImage:
                                                  "assets/images/dummy.png",
                                              description: "Kran patah di drat tembok, air meluap ke kamar tidur! Butuh bantuan segera sebelum banjir ke kasur.",
                                              mapImage:
                                                  "assets/images/dummy.png",
                                              addressDetail: _emergencyAddress,
                                              initialWage: 55000,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 130,
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
                if (_isLoadingNearby)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_nearbyError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_nearbyError!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _loadNearbyOffers,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  )
                else if (displayedOffers.isEmpty)
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
                          onPressed: _loadNearbyOffers,
                          child: const Text("Muat Ulang Tawaran"),
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
                      onTolakTap: null,
                      onDetailTap: () => _openTechnicianOffer(
                        Map<String, dynamic>.from(item['offer'] as Map),
                      ),
                    );
                  }),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Align(
                    alignment: Alignment.center,
                    child: MaterialButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListTawaranPage(),
                          ),
                        );
                      },
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
