import 'package:flutter/material.dart';

class HomePageUser extends StatefulWidget {
  const HomePageUser({super.key});

  @override
  State<HomePageUser> createState() => _HomePageUserState();
}

class _HomePageUserState extends State<HomePageUser> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
                  "User",
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
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Profil",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
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
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Tawaran Saya",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
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
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Obrolan",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
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
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Pengaturan",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
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
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  width: MediaQuery.of(context).size.width,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "Tentang Aplikasi",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.normal,
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
                // HEADER
                Container(
                  margin: const EdgeInsets.all(0),
                  padding: const EdgeInsets.all(10),
                  width: MediaQuery.of(context).size.width,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(0),
                        padding: const EdgeInsets.all(0),
                        decoration: const BoxDecoration(
                          color: Color(0x00000000),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
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
                            const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text(
                                  "BantuKilat",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 14,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                Text(
                                  "Beranda",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 10,
                                    color: Color(0xff707070),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                        child: Icon(
                          Icons.notifications,
                          color: Color(0xff141c2f),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // BANNER GAMBAR
                Image.asset(
                  "assets/images/dummy.png",
                  height: 200,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: MediaQuery.of(context).size.width,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(7, 0, 0, 0),
                        child: Text(
                          "Butuh Bantuan Apa?",
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            fontSize: 13,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // GRID KATEGORI LAYANAN
                Container(
                  margin: const EdgeInsets.all(0),
                  padding: const EdgeInsets.all(10),
                  width: MediaQuery.of(context).size.width,
                  height: 300,
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: GridView(
                    padding: const EdgeInsets.all(0),
                    shrinkWrap: false,
                    scrollDirection: Axis.vertical,
                    physics: const ScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.2,
                        ),
                    children: const [
                      // ==========================================================
                      // PEMANGGILAN CUSTOM WIDGET KATEGORI LAYANAN
                      // Kamu cukup panggil KategoriLayananCard(...) seperti ini!
                      // ==========================================================
                      KategoriLayananCard(
                        judul: "Kelistrikan",
                        icon: Icons.bolt,
                        warnaIcon: Color(0xff212435),
                        warnaContainerIcon: Color(0xffffddb7),
                        warnaContainerPojok: Color(0xffffddb7),
                      ),
                      KategoriLayananCard(
                        judul: "Saluran Air",
                        icon: Icons.water_drop,
                        warnaIcon: Color(0xff003366),
                        warnaContainerIcon: Color(0xffd0e8ff),
                        warnaContainerPojok: Color(0xffd0e8ff),
                      ),
                      KategoriLayananCard(
                        judul: "Atap & Dinding",
                        icon: Icons.roofing,
                        warnaIcon: Color(0xff004d34),
                        warnaContainerIcon: Color(0xffb8f5d8),
                        warnaContainerPojok: Color(0xffb8f5d8),
                      ),
                      KategoriLayananCard(
                        judul: "Kunci & Pintu",
                        icon: Icons.vpn_key,
                        warnaIcon: Color.fromARGB(255, 165, 135, 0),
                        warnaContainerIcon: Color(0xffffd6d6),
                        warnaContainerPojok: Color(0xffffd6d6),
                      ),
                      KategoriLayananCard(
                        judul: "Teknologi",
                        icon: Icons.laptop,
                        warnaIcon: Color.fromARGB(255, 254, 253, 253),
                        warnaContainerIcon: Color(0xff003366),
                        warnaContainerPojok: Color(0xff003366),
                      ),
                      KategoriLayananCard(
                        judul: "Kendaraan",
                        icon: Icons.car_repair,
                        warnaIcon: Color.fromARGB(255, 252, 252, 252),
                        warnaContainerIcon: Color.fromARGB(255, 0, 0, 0),
                        warnaContainerPojok: Color.fromARGB(255, 4, 4, 4),
                      ),
                      KategoriLayananCard(
                        judul: "Angkut Barang",
                        icon: Icons.card_travel_rounded,
                        warnaIcon: Color.fromARGB(255, 252, 252, 252),
                        warnaContainerIcon: Color.fromARGB(255, 121, 0, 69),
                        warnaContainerPojok: Color.fromARGB(255, 121, 0, 69),
                      ),
                      KategoriLayananCard(
                        judul: "Bantuan Lainnya",
                        icon: Icons.more_horiz_rounded,
                        warnaIcon: Color.fromARGB(255, 254, 253, 253),
                        warnaContainerIcon: Color.fromARGB(255, 71, 0, 177),
                        warnaContainerPojok: Color.fromARGB(255, 71, 0, 177),
                      ),
                    ],
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
// CUSTOM WIDGET: KategoriLayananCard
// Widget ini membungkus kodingan panjang Card di dalam GridView
// =========================================================================
class KategoriLayananCard extends StatelessWidget {
  final String judul;
  final IconData icon;
  final Color warnaIcon;
  final Color warnaContainerIcon;
  final Color warnaContainerPojok;
  final VoidCallback? onTap;

  const KategoriLayananCard({
    super.key,
    required this.judul,
    required this.icon,
    this.warnaIcon = const Color(0xff212435),
    required this.warnaContainerIcon,
    required this.warnaContainerPojok,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.all(4),
        color: const Color(0xffffffff),
        shadowColor: const Color(0xff000000),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(0),
                      padding: const EdgeInsets.all(0),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: warnaContainerIcon,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(icon, color: warnaIcon, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,

                      child: Text(
                        judul,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          fontSize: 14,
                          color: Color(0xff000000),
                        ),
                      ),
                    ),
                  ),
                  Container(),
                  Container(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(0),
                padding: const EdgeInsets.all(0),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: warnaContainerPojok,
                  shape: BoxShape.rectangle,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
