import 'package:bantukilat/page/DetailTawaran.dart';
import 'package:bantukilat/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

// ============================================================================
// 1. DEFINISI KATEGORI (ENUM)
// [HINT TAMBAH KATEGORI BARU - STEP 1]:
// Tambahkan nama kategori baru di dalam enum ini, misalnya:
// enum TaskCategory { ditugaskan, selesai, dibatalkan }
// ============================================================================
enum TaskCategory { ditugaskan, selesai }

// ============================================================================
// 2. MODEL DATA TUGAS
// Menyimpan semua properti yang dibutuhkan oleh setiap kartu tugas.
// ============================================================================
class TaskItem {
  final String id;
  TaskCategory category;
  final String
  statusSubtitle; // Contoh: "2 Hari yang lalu" untuk status selesai
  final String distance; // Contoh: "180 Meter" atau "2.5 KM"
  final String title;
  final String profileImage;
  final String clientName;
  final int
  wage; // Dalam angka murni (misal 50000) untuk dikirim ke DetailTawaran
  final String description;
  final String previewImage;
  final String addressDetail;
  final String? bidId;

  TaskItem({
    required this.id,
    required this.category,
    this.statusSubtitle = '',
    required this.distance,
    required this.title,
    required this.profileImage,
    required this.clientName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
    this.bidId,
  });
}

// ============================================================================
// 3. HALAMAN UTAMA (TUGAS SAYA)
// ============================================================================
class TugasSaya extends StatefulWidget {
  @override
  _TugasSayaState createState() => _TugasSayaState();
}

class _TugasSayaState extends State<TugasSaya> {
  // null berarti memilih filter "Semua"
  TaskCategory? _selectedFilter;

  bool _isLoadingTasks = true;
  String? _tasksError;
  double _latitude = -7.2575;
  double _longitude = 112.7521;
  final List<TaskItem> _allTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
      _tasksError = null;
    });
    try {
      try {
        final position = await Geolocator.getCurrentPosition();
        _latitude = position.latitude;
        _longitude = position.longitude;
      } catch (_) {}
      final tasks = await AuthService.getMyTasks(
        latitude: _latitude,
        longitude: _longitude,
      );
      final items = <TaskItem>[];
      for (final task in tasks) {
        final categorySnapshot = Map<String, dynamic>.from(
          (task['category_snapshot'] as Map?) ?? const {},
        );
        final requester = Map<String, dynamic>.from(
          (task['requester_snapshot'] as Map?) ?? const {},
        );
        final status = '${task['status'] ?? ''}'.toUpperCase();
        final category = status == 'COMPLETED'
            ? TaskCategory.selesai
            : TaskCategory.ditugaskan;
        final budget = task['agreed_price'] ?? task['initial_budget'] ?? 0;
        final photos =
            (task['photos'] as List?)?.cast<String>() ?? const <String>[];
        var preview = photos.isEmpty ? 'assets/images/dummy.png' : photos.first;
        if (preview != 'assets/images/dummy.png') {
          try {
            preview = await AuthService.getMediaUrl(preview);
          } catch (_) {}
        }
        items.add(
          TaskItem(
            id: '${task['_id']}',
            bidId: (task['accepted_bid'] as Map?)?['_id']?.toString(),
            category: category,
            statusSubtitle: status == 'COMPLETED' ? 'Selesai' : '',
            distance: '',
            title: '${task['title'] ?? categorySnapshot['label'] ?? ''}',
            profileImage: 'assets/logo/LogoBulat.png',
            clientName: '${requester['name'] ?? 'Pengguna'}',
            wage: budget is num ? budget.toInt() : int.tryParse('$budget') ?? 0,
            description: '${task['description'] ?? ''}',
            previewImage: preview,
            addressDetail: '${task['address_text'] ?? ''}',
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _allTasks
          ..clear()
          ..addAll(items);
        _isLoadingTasks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tasksError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingTasks = false;
      });
    }
  }

  /* DUMMY_TASKS
    TaskItem(
      id: '1',
      category: TaskCategory.ditugaskan,
      distance: '180 Meter',
      title: 'Pipa Kamar Mandi Meletup',
      profileImage: 'assets/logo/LogoBulat.png',
      clientName: 'Mas Amba',
      wage: 50000,
      description: 'Pipa kran patah dalam tembok, air menyembur deras. Butuh alat sok drat & seal tape.',
      previewImage: 'assets/images/dummy.png',
      addressDetail: 'Jl. Kalijudan Barat III No. 106',
    ),
    TaskItem(
      id: '2',
      category: TaskCategory.selesai,
      statusSubtitle: '2 Hari yang lalu',
      distance: '1.2 KM',
      title: 'Perbaikan Saklar Korslet',
      profileImage: 'assets/logo/LogoBulat.png',
      clientName: 'Pak Rusdi',
      wage: 75000,
      description:
          'Saklar ruang tamu bau gosong dan lampu sering kedip-kedip sendiri.',
      previewImage: 'assets/images/dummy.png',
      addressDetail: 'Jl. Dharmahusada Indah Blok A',
    ),
    TaskItem(
      id: '3',
      category: TaskCategory.selesai,
      statusSubtitle: '5 Hari yang lalu',
      distance: '450 Meter',
      title: 'Pasang Engsel Pintu Kayu',
      profileImage: 'assets/logo/LogoBulat.png',
      clientName: 'Bu Siti',
      wage: 40000,
      description: 'Engsel pintu kamar bawah lepas satu, pintu jadi miring dan susah ditutup.',
      previewImage: 'assets/images/dummy.png',
      addressDetail: 'Gg. Pacar Kembang II No. 14',
    ),
  */

  // Helper untuk menghitung jumlah tugas per kategori secara responsif
  int _countByCategory(TaskCategory category) {
    return _allTasks.where((task) => task.category == category).length;
  }

  // Helper untuk mengambil daftar tugas sesuai filter yang aktif
  List<TaskItem> get _filteredTasks {
    if (_selectedFilter == null) {
      return _allTasks;
    }
    return _allTasks.where((task) => task.category == _selectedFilter).toList();
  }

  // Fungsi untuk mengubah status tugas menjadi selesai saat di-slide ke kanan
  Future<void> _completeTask(String taskId) async {
    try {
      await AuthService.completeOffer(taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas berhasil dikonfirmasi selesai!'),
          backgroundColor: Color(0xff006b4a),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      await _loadTasks();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int countDitugaskan = _countByCategory(TaskCategory.ditugaskan);
    final int countSelesai = _countByCategory(TaskCategory.selesai);
    // [HINT TAMBAH KATEGORI BARU - STEP 2]:
    // Buat variabel hitungan baru jika ingin menampilkannya di bar atas / filter:
    // final int countDibatalkan = _countByCategory(TaskCategory.dibatalkan);

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
                      // BAGIAN 1: COUNTER CONTAINER ATAS (RESPONSIF)
                      // --------------------------------------------------------
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                        padding: EdgeInsets.all(10),
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
                                  count: countDitugaskan,
                                  label: "DITUGASKAN",
                                  bgColor: Color(0xffffdcd8),
                                  textColor: Color(0xffba1a1a),
                                ),
                                _buildSummaryBox(
                                  count: countSelesai,
                                  label: "SELESAI",
                                  bgColor: Color(0x6d86ffc8),
                                  textColor: Color(0xff006948),
                                ),
                                // [HINT]: Tambahkan _buildSummaryBox baru di sini jika perlu
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --------------------------------------------------------
                      // BAGIAN 2: FILTER CHIPS (BISA DIPENCET & PINDAH WARNA HIJAU)
                      // --------------------------------------------------------
                      Container(
                        margin: EdgeInsets.fromLTRB(0, 10, 0, 20),
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
                                label: "Semua (${_allTasks.length})",
                                isSelected: _selectedFilter == null,
                                onTap: () {
                                  setState(() => _selectedFilter = null);
                                },
                              ),
                              _buildFilterTab(
                                label: "Ditugaskan ($countDitugaskan)",
                                isSelected:
                                    _selectedFilter == TaskCategory.ditugaskan,
                                onTap: () {
                                  setState(
                                    () => _selectedFilter =
                                        TaskCategory.ditugaskan,
                                  );
                                },
                              ),
                              _buildFilterTab(
                                label: "Selesai ($countSelesai)",
                                isSelected:
                                    _selectedFilter == TaskCategory.selesai,
                                onTap: () {
                                  setState(
                                    () =>
                                        _selectedFilter = TaskCategory.selesai,
                                  );
                                },
                              ),
                              // [HINT TAMBAH KATEGORI BARU - STEP 3]:
                              // Tambahkan _buildFilterTab untuk kategori baru di sini
                            ],
                          ),
                        ),
                      ),

                      // --------------------------------------------------------
                      // BAGIAN 3: DAFTAR KARTU TUGAS (REUSABLE WIDGET)
                      // --------------------------------------------------------
                      if (_isLoadingTasks)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        )
                      else if (_tasksError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Text(_tasksError!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: _loadTasks,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        )
                      else if (_filteredTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            "Tidak ada tugas di kategori ini.",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ..._filteredTasks.map((task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: TaskCardWidget(
                              key: ValueKey(task.id),
                              category: task.category,
                              statusSubtitle: task.statusSubtitle,
                              distance: task.distance,
                              title: task.title,
                              profileImage: task.profileImage,
                              clientName: task.clientName,
                              wage: task.wage,
                              description: task.description,
                              previewImage: task.previewImage,
                              addressDetail: task.addressDetail,
                              bidId: task.bidId,
                              onSlideCompleted: () => _completeTask(task.id),
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
                          "Tugas Saya",
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
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
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

  // Helper Widget untuk Tombol Filter Kategori
  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.fromLTRB(0, 5, 10, 0),
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
    );
  }
}

// ============================================================================
// 4. REUSABLE WIDGET: KARTU TUGAS (TaskCardWidget)
// Bisa dipanggil di mana saja dengan mengirimkan parameter yang dibutuhkan.
// ============================================================================
class TaskCardWidget extends StatelessWidget {
  final String? bidId;
  final TaskCategory category;
  final String statusSubtitle;
  final String distance;
  final String title;
  final String profileImage;
  final String clientName;
  final int wage;
  final String description;
  final String previewImage;
  final String addressDetail;
  final VoidCallback? onSlideCompleted;

  const TaskCardWidget({
    Key? key,
    this.bidId,
    required this.category,
    this.statusSubtitle = '',
    required this.distance,
    required this.title,
    required this.profileImage,
    required this.clientName,
    required this.wage,
    required this.description,
    this.previewImage = 'assets/images/dummy.png',
    this.addressDetail = '',
    this.onSlideCompleted,
  }) : super(key: key);

  // Format angka integer ke format Rupiah sederhana (contoh: 50000 -> Rp 50.000)
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
    // ------------------------------------------------------------------------
    // KONFIGURASI TAMPILAN BERDASARKAN KATEGORI
    // [HINT TAMBAH KATEGORI BARU - STEP 4]:
    // Tambahkan case baru pada switch di bawah ini untuk mengatur warna garis atas,
    // warna badge, dan teks status kategori barumu.
    // ------------------------------------------------------------------------
    Color topBarColor;
    Color badgeBgColor;
    Color badgeDotColor;
    Color badgeTextColor;
    String badgeText;

    switch (category) {
      case TaskCategory.ditugaskan:
        topBarColor = Color(0xffba0011); // Garis merah untuk Ditugaskan
        badgeBgColor = Color(0xffffdbd7);
        badgeDotColor = Color(0xffbe0011);
        badgeTextColor = Color(0xff430002);
        badgeText = "DITUGASKAN";
        break;
      case TaskCategory.selesai:
        topBarColor = Color(0xff006b4a); // Garis hijau untuk Selesai
        badgeBgColor = Color(0xffeceeff);
        badgeDotColor = Color(0xff006b4a);
        badgeTextColor = Color(0xff006b4a);
        badgeText = statusSubtitle.isNotEmpty
            ? "Selesai - $statusSubtitle"
            : "SELESAI";
        break;
    }

    return Container(
      width: MediaQuery.of(context).size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Garis Penanda Kategori di Atas Container
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
            padding: EdgeInsets.all(12),
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
              children: [
                // Baris Badge Kategori & Jarak Lokasi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: badgeDotColor, size: 10),
                          Padding(
                            padding: EdgeInsets.all(5),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Color(0x6d86ffc8),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Color(0xff006747),
                            size: 14,
                          ),
                          SizedBox(width: 2),
                          Text(
                            distance,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: Color(0xff006948),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Judul Tugas
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

                // Foto Profil & Nama Pemesan
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        height: 35,
                        width: 35,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Image.asset(
                          profileImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.person, size: 20),
                              ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                        child: Text(
                          clientName,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
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
                        padding: EdgeInsets.only(bottom: 5),
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
                        padding: EdgeInsets.only(bottom: 15),
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

                // Tombol Detail (Menyesuaikan isi data konten kartu)
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
                              offerId: null,
                              bidId: bidId,
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
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
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

                // Tombol Slide untuk Selesai (Hanya muncul jika status masih Ditugaskan)
                if (category == TaskCategory.ditugaskan)
                  SlideToCompleteButton(
                    onCompleted: () {
                      if (onSlideCompleted != null) {
                        onSlideCompleted!();
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. WIDGET TOMBOL GESER (SLIDE TO COMPLETE)
// Mendukung interaksi geser ke kanan untuk mengonfirmasi penyelesaian tugas.
// ============================================================================
class SlideToCompleteButton extends StatefulWidget {
  final VoidCallback onCompleted;

  const SlideToCompleteButton({Key? key, required this.onCompleted})
    : super(key: key);

  @override
  _SlideToCompleteButtonState createState() => _SlideToCompleteButtonState();
}

class _SlideToCompleteButtonState extends State<SlideToCompleteButton> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double knobSize = 50.0;
        final double maxDrag = maxWidth - knobSize;

        return Container(
          width: maxWidth,
          height: knobSize,
          clipBehavior:
              Clip.antiAlias, // Memastikan isi tidak keluar dari lengkungan
          decoration: BoxDecoration(
            color: Color(0xff84ffc7),
            borderRadius: BorderRadius.circular(50.0),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. LAYER PALING BAWAH: Teks Tengah (Akan tertutup saat digeser)
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Selesai",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xff006546),
                      ),
                    ),
                    Text(
                      "Geser untuk Konfirmasi",
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Color(0xff006a49),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. LAYER TENGAH: Container baru yang ikut memanjang menutupi teks
              Positioned(
                left: 0,
                child: Container(
                  // Lebarnya mengikuti posisi geseran + ukuran lingkaran tombol
                  width: _dragPosition + knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: Color(0xff006b4a), // Warna hijau tua penutup
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  // Opsional: Teks konfirmasi yang muncul di dalam container baru saat digeser
                  child: _dragPosition > 60
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: knobSize * 0.6),
                            child: Text(
                              "Lepas untuk Selesai",
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),

              // 3. LAYER PALING ATAS: Lingkaran Panah yang Bisa Digeser ke Kanan
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCompleted) return;
                    // Jika digeser melewati 80% lebar track, anggap selesai
                    if (_dragPosition >= maxDrag * 0.8) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCompleted = true;
                      });
                      Future.delayed(Duration(milliseconds: 150), () {
                        widget.onCompleted();
                      });
                    } else {
                      // Jika belum sampai ujung, kembalikan ke posisi kiri
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: Color(0xffeceeff),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isCompleted ? Icons.check : Icons.arrow_forward,
                      color: Color(0xff006646),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
