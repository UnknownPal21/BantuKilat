import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class TawaranSaya extends StatefulWidget {
  const TawaranSaya({super.key});

  @override
  State<TawaranSaya> createState() => _TawaranSayaState();
}

class _TawaranSayaState extends State<TawaranSaya> {
  final TextEditingController _alamatController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // State Foto Bukti Masalah (disimpan di memory sementara & otomatis ter-lock)
  Uint8List? _selectedImageBytes;
  bool _isPhotoLocked = false;

  // State Lokasi GPS
  bool _isLoadingLocation = false;
  double? _currentLat;
  double? _currentLng;

  // State Mode SOS
  bool _isSosActive = true;

  // State Tawaran Imbalan Awal (Style sama dengan DetailTawaran)
  // 0 = Rp 15.000, 1 = Rp 25.000, 2 = Rp 40.000, 3 = Custom
  int _selectedWageIndex = 0;
  int? _customWageAmount;
  final List<int> _presetWages = [15000, 25000, 40000];

  int get _activeWage {
    if (_selectedWageIndex == 3 && _customWageAmount != null) {
      return _customWageAmount!;
    }
    return _presetWages[_selectedWageIndex];
  }

  String _formatRupiah(int amount) {
    final str = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  @override
  void dispose() {
    _alamatController.dispose();
    super.dispose();
  }

  // 1. Fungsi Pilih Foto (Kamera / Galeri) & Otomatis Lock
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _selectedImageBytes = bytes;
            _isPhotoLocked = true; // Otomatis ke-lock begitu foto terpilih
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto bukti berhasil dipilih dan dikunci!'),
              backgroundColor: Color(0xff006747),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageSourceBottomSheet() {
    if (_isPhotoLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto sudah dikunci. Klik tombol "Buka Kunci" di pojok kiri atas foto jika ingin mengganti.',
          ),
          backgroundColor: Color(0xff613c00),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Text(
                  "Pilih Sumber Foto Bukti",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xff1e2621),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff006747).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xff006747),
                    ),
                  ),
                  title: const Text(
                    "Ambil Foto dari Kamera",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Potret langsung bagian yang rusak",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff006747).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xff006747),
                    ),
                  ),
                  title: const Text(
                    "Pilih dari Galeri / File",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Pilih gambar yang sudah tersimpan di perangkat",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. Fungsi Deteksi Lokasi dengan Geolocator + OpenStreetMap HTTP (Bebas Error Geocoding!)
  Future<void> _getLocationAndFillAddress() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'GPS tidak aktif. Silakan nyalakan layanan lokasi di HP Anda.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Aktifkan melalui Pengaturan HP.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLat = position.latitude;
      _currentLng = position.longitude;

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BantuKilatApp/1.0 (logicodix2026)',
          'Accept-Language': 'id',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final String fullAddress = data['display_name'] ?? '';

        setState(() {
          _alamatController.text = fullAddress;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi berhasil dilacak dan diisi ke alamat!'),
            backgroundColor: Color(0xff006747),
          ),
        );
      } else {
        throw 'Gagal mengambil detail alamat dari koordinat.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // 3. Pop-up Input Imbalan Custom (Style persis DetailTawaran)
  Future<void> _showCustomWageModal() async {
    final TextEditingController customCtrl = TextEditingController(
      text: _customWageAmount != null
          ? _customWageAmount.toString()
          : _activeWage.toString(),
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
                            color: const Color(0xff006a49).withOpacity(0.12),
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
                                "Imbalan Awal Custom",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xff1e2621),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Masukkan nominal upah yang ingin Anda tawarkan",
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
                        hintText: "30000",
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
                              if (parsed == null || parsed < 5000) {
                                setModalState(() {
                                  errorMessage = "Minimal imbalan Rp 5.000";
                                });
                                return;
                              }
                              setState(() {
                                _customWageAmount = parsed;
                                _selectedWageIndex = 3;
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
    final int totalEstimation = _activeWage + (_isSosActive ? 10000 : 0);

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xfff7f4ff),
        body: Stack(
          alignment: Alignment.topLeft,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 65, 10, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // CARD 1: Foto Bukti Masalah
                    Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: const Color(0xffffffff),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Foto Bukti Masalah",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xff000000),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isPhotoLocked
                                          ? const Color(0xffd4f5e9)
                                          : const Color(0xfffed8d4),
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isPhotoLocked) ...[
                                          const Icon(
                                            Icons.lock,
                                            size: 12,
                                            color: Color(0xff006747),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          _isPhotoLocked
                                              ? "Foto Terkunci"
                                              : "Wajib Foto",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: _isPhotoLocked
                                                ? const Color(0xff006747)
                                                : const Color(0xff3d0002),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: _showImageSourceBottomSheet,
                                child: Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0),
                                      child: _selectedImageBytes != null
                                          ? Image.memory(
                                              _selectedImageBytes!,
                                              height: 165,
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.asset(
                                              "assets/images/dummy.png",
                                              height: 165,
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    if (_isPhotoLocked)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isPhotoLocked = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Kunci foto dibuka. Anda dapat memilih ulang foto.',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.65,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock_open,
                                                  color: Colors.white,
                                                  size: 13,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  "Buka Kunci",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isPhotoLocked
                                              ? const Color(0xff006747)
                                              : const Color(0xe2ffffff),
                                          borderRadius: BorderRadius.circular(
                                            20.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isPhotoLocked
                                                  ? Icons.check_circle
                                                  : Icons.photo_camera,
                                              color: _isPhotoLocked
                                                  ? Colors.white
                                                  : const Color(0xff212435),
                                              size: 15,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _isPhotoLocked
                                                  ? "Terkunci"
                                                  : "Pilih / Ambil Foto",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                                color: _isPhotoLocked
                                                    ? Colors.white
                                                    : const Color(0xff000000),
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
                            Container(
                              width: MediaQuery.of(context).size.width,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xffffdebb),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.lightbulb_circle,
                                      color: Color(0xff613c00),
                                      size: 16,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Foto wajib jelas agar tukang otomatis membawa peralatan yang sesuai dengan kerusakannya.",
                                      textAlign: TextAlign.justify,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Color(0xff663f00),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // CARD 2: Lokasi & Detail Alamat
                    Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: const Color(0xffffffff),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Lokasi",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xff000000),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.asset(
                                  "assets/images/dummy.png",
                                  height: 180,
                                  width: MediaQuery.of(context).size.width,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 4,
                              ),
                              child: MaterialButton(
                                onPressed: _isLoadingLocation
                                    ? null
                                    : _getLocationAndFillAddress,
                                color: const Color(0xff006747),
                                disabledColor: Colors.grey.shade400,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.all(12),
                                textColor: const Color(0xffffffff),
                                height: 45,
                                minWidth: MediaQuery.of(context).size.width,
                                child: _isLoadingLocation
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.my_location, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Deteksi Lokasi Saya Sekarang",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Detail Alamat",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Color(0xff000000),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: TextField(
                                controller: _alamatController,
                                maxLines: 4,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                  color: Color(0xff000000),
                                ),
                                decoration: InputDecoration(
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xff3d4a42),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xff006747),
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: const BorderSide(
                                      color: Color(0xff3d4a42),
                                      width: 1,
                                    ),
                                  ),
                                  hintText: "Klik tombol Deteksi Lokasi di atas atau ketik alamat lengkap secara manual...",
                                  hintStyle: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    color: Color(0xffa4a4a4),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xfff2f3ff),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // CARD 3: Mode SOS Darurat
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: MediaQuery.of(context).size.width,
                      child: Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                              color: const Color(0xffffdad5),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Color(0xffb80011),
                                          size: 24,
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: Text(
                                            "Mode SOS Darurat",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xff93000a),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff91000a),
                                        borderRadius: BorderRadius.circular(
                                          5.0,
                                        ),
                                      ),
                                      child: const Text(
                                        "PRIORITAS",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                          color: Color(0xffffffff),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          "Bunyikan alarm prioritas di HP tetangga terdekat agar sampai dalam 5-10 menit. (terkena fee tambahan Rp. 10.000)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10,
                                            color: Color(0xff90000a),
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: _isSosActive,
                                        onChanged: (value) {
                                          setState(() {
                                            _isSosActive = value;
                                          });
                                        },
                                        activeColor: const Color(0xffffffff),
                                        activeTrackColor: const Color(
                                          0xffba0011,
                                        ),
                                        inactiveThumbColor: const Color(
                                          0xff9e9e9e,
                                        ),
                                        inactiveTrackColor: const Color(
                                          0xffe0e0e0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: Color(0x24bc0011),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(600.0),
                                    bottomRight: Radius.circular(10.0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CARD 4: Tawaran Imbalan Awal
                    Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: const Color(0xffffffff),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text(
                                "Tawaran Imbalan Awal",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xff000000),
                                ),
                              ),
                            ),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Nominal Imbalan Jasa",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11,
                                              color: Color(0xff3d4b42),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatRupiah(_activeWage),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 20,
                                              color: Color(0xff006a49),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isSosActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffffdad5),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            "+ Rp 10.000 (SOS)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              color: Color(0xff93000a),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Pilih Nominal Imbalan",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: Color(0xff404e46),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...List.generate(_presetWages.length, (
                                          index,
                                        ) {
                                          final int wage = _presetWages[index];
                                          final bool isSelected =
                                              _selectedWageIndex == index;
                                          final List<String> labels = [
                                            "Ringan",
                                            "Standar",
                                            "Berat",
                                          ];

                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedWageIndex = index;
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
                                                    ? const Color(0xff006a49)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(15.0),
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    labels[index],
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
                                                    _formatRupiah(wage),
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
                                        }),
                                        GestureDetector(
                                          onTap: _showCustomWageModal,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            width: 105,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _selectedWageIndex == 3
                                                  ? const Color(0xff006a49)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(15.0),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.edit,
                                                      size: 12,
                                                      color:
                                                          _selectedWageIndex ==
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
                                                            _selectedWageIndex ==
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
                                                  _selectedWageIndex == 3 &&
                                                          _customWageAmount !=
                                                              null
                                                      ? _formatRupiah(
                                                          _customWageAmount!,
                                                        )
                                                      : "Atur Harga",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color:
                                                        _selectedWageIndex == 3
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
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                      "Tukang dapat menyetujui tawaran ini atau menawar harga",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 11,
                                        color: Color(0xff3e4b43),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // TOMBOL SUBMIT: Kirim Permintaan
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                      child: MaterialButton(
                        onPressed: () {
                          if (_selectedImageBytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mohon unggah atau ambil Foto Bukti Masalah terlebih dahulu!',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          if (_alamatController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mohon lengkapi Detail Alamat terlebih dahulu!',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Permintaan dikirim dengan total ${_formatRupiah(totalEstimation)}!',
                              ),
                              backgroundColor: const Color(0xff006747),
                            ),
                          );
                        },
                        color: const Color(0xff006747),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.all(16),
                        textColor: const Color(0xffffffff),
                        height: 50,
                        minWidth: MediaQuery.of(context).size.width,
                        child: Text(
                          "Kirim Permintaan (${_formatRupiah(totalEstimation)})",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // HEADER BAR
            Container(
              width: MediaQuery.of(context).size.width,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xfff8f5ff),
                border: Border.all(color: const Color(0x4d9e9e9e), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.maybePop(context);
                      },
                      color: const Color(0xff212435),
                      iconSize: 24,
                    ),
                    const Text(
                      "Panggil Bantuan",
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
          ],
        ),
      ),
    );
  }
}
