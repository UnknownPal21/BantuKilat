import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class DetailTawaran extends StatefulWidget {
  final String title;
  final String customerName;
  final String customerAvatar;
  final String previewImage;
  final String description;
  final String mapImage;
  final String addressDetail;
  final int initialWage;

  const DetailTawaran({
    super.key,
    required this.title,
    required this.previewImage,
    required this.description,
    required this.addressDetail,
    required this.initialWage,
    this.customerName = "Mr Amba",
    this.customerAvatar = "assets/logo/LogoBulat.png",
    this.mapImage = "assets/images/dummy.png",
  });

  @override
  State<DetailTawaran> createState() => _DetailTawaranState();
}

class _DetailTawaranState extends State<DetailTawaran> {
  // null = belum pilih nego, 0 = +5rb, 1 = +15rb, 2 = +30rb, 3 = custom
  int? _selectedNegoIndex;
  int? _customNegotiatedTotal;

  final List<int> _presetIncrements = [5000, 15000, 30000];

  // State & Controller untuk pelacakan lokasi peta berdasarkan teks addressDetail
  final MapController _previewMapController = MapController();
  LatLng _trackedLocation = const LatLng(
    -7.2575,
    112.7521,
  ); // Default fallback (Surabaya)
  bool _isSearchingLocation = true;

  @override
  void initState() {
    super.initState();
    _geocodeAddressFromText();
  }

  @override
  void didUpdateWidget(covariant DetailTawaran oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addressDetail != widget.addressDetail) {
      _geocodeAddressFromText();
    }
  }

  // Menghasilkan daftar variasi kueri dari yang paling spesifik hingga nama jalan utama
  List<String> _buildSearchQueries(String raw) {
    final List<String> queries = [];

    void addUnique(String q) {
      final clean = q.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isNotEmpty && !queries.contains(clean)) {
        queries.add(clean);
      }
    }

    // 1. Ganti singkatan umum ("Jl." -> "Jalan", "Gg." -> "Gang")
    String expanded = raw
        .replaceAll(RegExp(r'\bJl\.?\s*', caseSensitive: false), 'Jalan ')
        .replaceAll(RegExp(r'\bGg\.?\s*', caseSensitive: false), 'Gang ');
    addUnique(expanded);

    // 2. Hapus nomor rumah, RT/RW, dan blok yang bikin OSM gagal mencocokkan jalan
    String withoutNumbers = expanded
        .replaceAll(
          RegExp(r'\bNo\.?\s*\d+[a-zA-Z]?\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\bRT\.?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bRW\.?\s*\d+\b', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\bBlok\s*[a-zA-Z0-9]+\b', caseSensitive: false),
          '',
        );
    addUnique(withoutNumbers);

    // 3. Hapus angka Romawi gang (I, II, III, IV, V, dst.) sebelum koma
    String withoutRoman = withoutNumbers.replaceAll(
      RegExp(r'\s+\b(I|II|III|IV|V|VI|VII|VIII|IX|X|\d+)\b(?=\s*,|$)'),
      '',
    );
    addUnique(withoutRoman);

    // 4. Hapus kata arah/sub-jalan ("Barat", "Timur", "Utara", "Selatan", "Tengah")
    // jika di OSM hanya terdaftar nama jalan utamanya (misal: "Jalan Kalijudan, Surabaya")
    String mainRoadOnly = withoutRoman.replaceAll(
      RegExp(
        r'\s+\b(Barat|Timur|Utara|Selatan|Tengah)\b(?=\s*,|$)',
        caseSensitive: false,
      ),
      '',
    );
    addUnique(mainRoadOnly);

    // 5. Jika tidak ada kata "Surabaya", tambahkan konteks Surabaya agar tidak nyasar ke luar kota
    if (!raw.toLowerCase().contains('surabaya')) {
      addUnique('$withoutRoman, Surabaya');
      addUnique('$mainRoadOnly, Surabaya');
    }

    // 6. Coba juga teks asli apa adanya
    addUnique(raw);

    return queries;
  }

  // Melacak koordinat otomatis dari teks widget.addressDetail menggunakan Nominatim OSM
  Future<void> _geocodeAddressFromText() async {
    final String rawQuery = widget.addressDetail.trim();
    if (rawQuery.isEmpty) {
      if (mounted) setState(() => _isSearchingLocation = false);
      return;
    }

    if (mounted) setState(() => _isSearchingLocation = true);

    try {
      LatLng? result;
      final List<String> candidates = _buildSearchQueries(rawQuery);

      for (final q in candidates) {
        result = await _fetchCoordinates(q);
        if (result != null) break;
      }

      if (result != null && mounted) {
        setState(() {
          _trackedLocation = result!;
          _isSearchingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _previewMapController.move(_trackedLocation, 15.5);
          } catch (_) {}
        });
      } else {
        if (mounted) setState(() => _isSearchingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  Future<LatLng?> _fetchCoordinates(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=id',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'BantuKilatApp/1.0 (flutter_map)'},
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        final double lat = double.parse(data[0]['lat']);
        final double lon = double.parse(data[0]['lon']);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  // Fungsi membuka Peta secara Full Screen & Interaktif (mengikuti style dialog sebelumnya)
  void _openFullScreenMap() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _trackedLocation,
                  initialZoom: 16.0,
                  minZoom: 5.0,
                  maxZoom: 19.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bantukilat.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _trackedLocation,
                        width: 60,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xff006a49),
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              right: 75,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xff00e699),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Lokasi: ${widget.addressDetail}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 35,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi helper untuk format angka ke "Rp 15.000" tanpa package tambahan
  String _formatRupiah(int amount) {
    final str = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  // Menghitung total harga nego yang aktif saat ini
  int? get _activeNegotiatedPrice {
    if (_selectedNegoIndex == null) return null;
    if (_selectedNegoIndex == 3) return _customNegotiatedTotal;
    return widget.initialWage + _presetIncrements[_selectedNegoIndex!];
  }

  // Fungsi membuka gambar secara Full Screen (bisa dicubit/zoom)
  void _openFullScreenImage(String imagePath, String label) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: _buildAdaptiveImage(
                imagePath,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.8,
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 35,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mendukung AssetImage maupun URL internet jika nanti disambung ke FastAPI
  Widget _buildAdaptiveImage(
    String path, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _imageErrorFallback(height, width),
      );
    }
    return Image.asset(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => _imageErrorFallback(height, width),
    );
  }

  Widget _imageErrorFallback(double? height, double? width) {
    return Container(
      height: height,
      width: width,
      color: const Color(0xffe0e4f5),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
    );
  }

  // Pop-up modern untuk input nominal Nego Custom
  Future<void> _showCustomPriceModal() async {
    final TextEditingController customCtrl = TextEditingController(
      text: _customNegotiatedTotal != null
          ? _customNegotiatedTotal.toString()
          : (widget.initialWage + 20000).toString(),
    );
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xff006a49)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xff006a49),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Tawaran Harga Custom",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xff1e2621),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Masukkan total upah yang Anda ajukan",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff717e76),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfff3f4ff),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Upah Awal Pelanggan:",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff404e46),
                            ),
                          ),
                          Text(
                            _formatRupiah(widget.initialWage),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff006a49),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff006a49),
                      ),
                      decoration: InputDecoration(
                        prefixText: "Rp ",
                        prefixStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff006a49),
                        ),
                        hintText: "35000",
                        errorText: errorMessage,
                        filled: true,
                        fillColor: const Color(0xfff8f9ff),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xffd0d7de),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xff006a49),
                            width: 1.8,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xffc5cdc8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Batal",
                              style: TextStyle(
                                color: Color(0xff404e46),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = int.tryParse(
                                customCtrl.text.trim(),
                              );
                              if (parsed == null || parsed <= 0) {
                                setModalState(() {
                                  errorMessage = "Masukkan nominal yang valid";
                                });
                                return;
                              }
                              if (parsed <= widget.initialWage) {
                                setModalState(() {
                                  errorMessage =
                                      "Harus di atas ${_formatRupiah(widget.initialWage)}";
                                });
                                return;
                              }
                              setState(() {
                                _customNegotiatedTotal = parsed;
                                _selectedNegoIndex = 3;
                              });
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff006a49),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Simpan Harga",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasNegoSelected = _activeNegotiatedPrice != null;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xfff8f5ff),
        body: Stack(
          alignment: Alignment.topLeft,
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 55),
                  Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      // Gambar 1: Preview Kerusakan (Klik untuk Full Screen)
                      GestureDetector(
                        onTap: () => _openFullScreenImage(
                          widget.previewImage,
                          widget.title,
                        ),
                        child: Stack(
                          children: [
                            _buildAdaptiveImage(
                              widget.previewImage,
                              height: 220,
                              width: MediaQuery.of(context).size.width,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Perbesar",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kontainer Detail di Bawah Gambar
                      Container(
                        margin: const EdgeInsets.fromLTRB(0, 175, 0, 0),
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          color: const Color(0xfff9f6ff),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24.0),
                            topRight: Radius.circular(24.0),
                          ),
                          border: Border.all(
                            color: const Color(0x2a000000),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Judul Kerusakan
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xff000000),
                                ),
                              ),
                              // Info Pelanggan
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 42,
                                      width: 42,
                                      margin: const EdgeInsets.only(right: 8),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: _buildAdaptiveImage(
                                        widget.customerAvatar,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Text(
                                      widget.customerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Deskripsi Kerusakan
                              Container(
                                width: MediaQuery.of(context).size.width,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeaedff),
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                child: Text(
                                  widget.description,
                                  textAlign: TextAlign.justify,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: Color(0xff3d4a42),
                                  ),
                                ),
                              ),
                              // Gambar 2: Peta Lokasi Dinamis (Melacak dari teks addressDetail & Klik untuk Full Screen)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: GestureDetector(
                                  onTap: _openFullScreenMap,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      height: 185,
                                      width: MediaQuery.of(context).size.width,
                                      child: Stack(
                                        children: [
                                          // Peta dikunci dari gesture langsung agar tidak mengganggu scroll halaman,
                                          // dan ketika diklik akan membuka _openFullScreenMap
                                          IgnorePointer(
                                            child: FlutterMap(
                                              mapController:
                                                  _previewMapController,
                                              options: MapOptions(
                                                initialCenter: _trackedLocation,
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
                                                      point: _trackedLocation,
                                                      width: 50,
                                                      height: 50,
                                                      alignment:
                                                          Alignment.topCenter,
                                                      child: const Icon(
                                                        Icons.location_on,
                                                        color: Color(
                                                          0xff006a49,
                                                        ),
                                                        size: 38,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_isSearchingLocation)
                                            Container(
                                              color: Colors.black12,
                                              alignment: Alignment.center,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(
                                                              0xff006a49,
                                                            ),
                                                          ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Melacak lokasi...",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xff006a49,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.zoom_out_map,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "Lihat Peta",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
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
                                ),
                              ),
                              // Detail Alamat
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Color(0xff006a49),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Lokasi: ${widget.addressDetail}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          color: Color(0xff000000),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tawaran Upah Awal
                              Container(
                                width: MediaQuery.of(context).size.width,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe7ebff),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Tawaran Upah:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: Color(0xff3c4941),
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(widget.initialWage),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xff006a49),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Section Nego Harga
                              Container(
                                width: MediaQuery.of(context).size.width,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeaedff),
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Text(
                                        "Nego Harga",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xff000000),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Pilih Nominal Kenaikan",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            color: Color(0xff404e46),
                                          ),
                                        ),
                                        if (hasNegoSelected)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedNegoIndex = null;
                                              });
                                            },
                                            child: const Text(
                                              "Reset Nego",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          // 3 Tombol Preset (+5.000, +15.000, +30.000)
                                          ...List.generate(
                                            _presetIncrements.length,
                                            (index) {
                                              final int inc =
                                                  _presetIncrements[index];
                                              final int total =
                                                  widget.initialWage + inc;
                                              final bool isSelected =
                                                  _selectedNegoIndex == index;

                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    // Jika diklik ulang tombol yang sama, batalkan pilihan
                                                    if (_selectedNegoIndex ==
                                                        index) {
                                                      _selectedNegoIndex = null;
                                                    } else {
                                                      _selectedNegoIndex =
                                                          index;
                                                    }
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  margin: const EdgeInsets.only(
                                                    right: 10,
                                                  ),
                                                  width: 105,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xff006a49,
                                                          )
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          15.0,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xff006a49,
                                                            )
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        "+ ${_formatRupiah(inc)}",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 10,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xff717e76,
                                                                ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        _formatRupiah(total),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xff000000,
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          // Tombol ke-4: Custom Nego dengan Ikon Pensil
                                          GestureDetector(
                                            onTap: _showCustomPriceModal,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              width: 105,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _selectedNegoIndex == 3
                                                    ? const Color(0xff006a49)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(15.0),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        size: 12,
                                                        color:
                                                            _selectedNegoIndex ==
                                                                3
                                                            ? Colors.white
                                                            : const Color(
                                                                0xff717e76,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "Custom",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 10,
                                                          color:
                                                              _selectedNegoIndex ==
                                                                  3
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xff717e76,
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    _selectedNegoIndex == 3 &&
                                                            _customNegotiatedTotal !=
                                                                null
                                                        ? _formatRupiah(
                                                            _customNegotiatedTotal!,
                                                          )
                                                        : "Atur Harga",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                      color:
                                                          _selectedNegoIndex ==
                                                              3
                                                          ? Colors.white
                                                          : const Color(
                                                              0xff000000,
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
                                    const SizedBox(height: 16),
                                    // Baris Tombol Terima & Kirim Tawaran
                                    Row(
                                      children: [
                                        // Tombol Terima (Selalu tampil dengan harga awal/default)
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            onTap: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Order diterima dengan upah awal ${_formatRupiah(widget.initialWage)}",
                                                  ),
                                                  backgroundColor: const Color(
                                                    0xff006a49,
                                                  ),
                                                ),
                                              );
                                              // TODO: Panggil endpoint FastAPI untuk Accept Order
                                            },
                                            child: Card(
                                              margin: const EdgeInsets.all(4),
                                              color: Colors.white,
                                              elevation: 1,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15.0),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                child: Column(
                                                  children: [
                                                    const Text(
                                                      "Terima",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xff3f4c44,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatRupiah(
                                                        widget.initialWage,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xff006243,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Tombol Kirim Tawaran (Hanya muncul jika ada opsi nego yang dipilih)
                                        if (hasNegoSelected) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              onTap: () {
                                                final int finalNego =
                                                    _activeNegotiatedPrice!;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Tawaran nego ${_formatRupiah(finalNego)} berhasil dikirim!",
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xff006a49),
                                                  ),
                                                );
                                                // TODO: Panggil endpoint FastAPI untuk Kirim Tawaran Nego (finalNego)
                                              },
                                              child: Card(
                                                margin: const EdgeInsets.all(4),
                                                color: const Color(0xff006a49),
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        15.0,
                                                      ),
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      const Text(
                                                        "Kirim Tawaran",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 11,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _formatRupiah(
                                                          _activeNegotiatedPrice!,
                                                        ),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Top App Bar
            Container(
              width: MediaQuery.of(context).size.width,
              height: 55,
              color: const Color(0xfff9f6ff),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: const Color(0xff212435),
                    iconSize: 24,
                  ),
                  const Text(
                    "Detail Tawaran",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xff000000),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
