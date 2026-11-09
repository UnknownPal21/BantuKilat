import 'package:flutter/material.dart';

class HomePageTeknisi extends StatefulWidget {
  const HomePageTeknisi({super.key});

  @override
  State<HomePageTeknisi> createState() => _HomePageTeknisiState();
}

class _HomePageTeknisiState extends State<HomePageTeknisi> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isSiagaAktif = true;

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
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 0,
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
                        "List Tawaran",
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
                        "Tugas",
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
                    vertical: 0,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
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
                          Container(
                            margin: const EdgeInsets.all(0),
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff88ffc9),
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xff006848),
                                  size: 10,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Mode Siaga Aktif",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 10,
                                    color: Color(0xff006b4a),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isSiagaAktif,
                            onChanged: (value) {
                              setState(() {
                                isSiagaAktif = value;
                              });
                            },
                            activeColor: const Color(0xffffffff),
                            activeTrackColor: const Color(0xff006243),
                            inactiveThumbColor: const Color(0xff9e9e9e),
                            inactiveTrackColor: const Color(0xffe0e0e0),
                          ),
                        ],
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
                const SizedBox(height: 15),

                // KARTU DARURAT UTAMA
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 8,
                  ),
                  padding: const EdgeInsets.all(0),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: const Color(0x00ffffff),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(0),
                        padding: const EdgeInsets.all(0),
                        width: MediaQuery.of(context).size.width,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xffff0000),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(0),
                        padding: const EdgeInsets.all(15),
                        width: MediaQuery.of(context).size.width,
                        decoration: const BoxDecoration(
                          color: Color(0xffffffff),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  margin: const EdgeInsets.all(0),
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffcd6d2),
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          5,
                                          0,
                                          0,
                                          0,
                                        ),
                                        child: Icon(
                                          Icons.circle,
                                          color: Color(0xffbe0011),
                                          size: 10,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 0,
                                          horizontal: 5,
                                        ),
                                        child: Text(
                                          "Darurat - 180 M",
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontStyle: FontStyle.normal,
                                            fontSize: 10,
                                            color: Color(0xffba0011),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(0),
                                  padding: const EdgeInsets.all(0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffe2e7ff),
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Text(
                                      "Baru Saja",
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontStyle: FontStyle.normal,
                                        fontSize: 10,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Kran Pipa Jebol & Air Meluap",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 14,
                                    color: Color(0xff000000),
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Color(0xffe02928),
                                    size: 15,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Ibu Ratna",
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.normal,
                                      fontSize: 12,
                                      color: Color(0xff000000),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Image.asset(
                              "assets/images/dummy.png",
                              height: 125,
                              width: MediaQuery.of(context).size.width,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 125,
                                  width: MediaQuery.of(context).size.width,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.all(0),
                                    padding: const EdgeInsets.all(0),
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff006948),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0x4d9e9e9e),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      5,
                                      0,
                                      0,
                                      0,
                                    ),
                                    padding: const EdgeInsets.all(0),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff7f4ff),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0x4d9e9e9e),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Lokasi: RT 02 No. 14, Depan Pos Ronda",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 10,
                                    color: Color(0xff000000),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.all(0),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0x65ffddb9),
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 5,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          0,
                                          0,
                                          0,
                                          5,
                                        ),
                                        child: Text(
                                          "Tawaran Upah",
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontStyle: FontStyle.normal,
                                            fontSize: 10,
                                            color: Color(0xff845200),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "Rp 55.000",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontStyle: FontStyle.normal,
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
                              padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.all(0),
                                    padding: const EdgeInsets.all(0),
                                    width: 110,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xffe52a28),
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: const Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Tolak",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.normal,
                                          fontSize: 13,
                                          color: Color(0xffffffff),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(0),
                                    padding: const EdgeInsets.all(0),
                                    width: 110,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff006546),
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: const Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Detail Tawaran",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.normal,
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

                // JUDUL TAWARAN SEKITAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Text(
                        "Tawaran Sekitar",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          fontSize: 14,
                          color: Color(0xff000000),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(0),
                        padding: const EdgeInsets.all(0),
                        decoration: BoxDecoration(
                          color: const Color(0xff86fac5),
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(5, 2, 5, 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Icon(
                                Icons.circle,
                                color: Color(0xff006646),
                                size: 10,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 5,
                                ),
                                child: Text(
                                  "3 Menunggu",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 10,
                                    color: Color(0xff006646),
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

                // ==========================================================
                // PEMANGGILAN CUSTOM WIDGET TAWARAN USER
                // Kamu cukup panggil TawaranUserCard(...) seperti di bawah ini!
                // ==========================================================
                const TawaranUserCard(
                  namaUser: "User 123",
                  jarak: "320 Meter",
                  tipeKerusakan: "Kelistrikan",
                  warnaContainerTipe: Color(0xffffddb8),
                  warnaTextTipe: Color(0xff2c1800),
                  judulKerusakan: "Stopkontak bau gosong",
                  deskripsiKerusakan:
                      "Perlu dicek sekring utama, kabel jalur ruang tamu bau…",
                  upah: "Rp 35.000",
                ),

                // Contoh tambahan kalau kamu mau nambah tawaran kedua (Air/Pipa):
                const TawaranUserCard(
                  namaUser: "Pak Budi",
                  jarak: "450 Meter",
                  tipeKerusakan: "Saluran Air",
                  warnaContainerTipe: Color(0xffd0e8ff),
                  warnaTextTipe: Color(0xff003366),
                  judulKerusakan: "Wastafel Dapur Mampet",
                  deskripsiKerusakan: "Air pembuangan cucian piring tidak mau turun sama sekali.",
                  upah: "Rp 40.000",
                ),
                TawaranUserCard(
                  namaUser: "Bu Yan",
                  jarak: "500 Meter",
                  tipeKerusakan: "Lainnya",
                  warnaContainerTipe: Color(0xffd0e8ff),
                  judulKerusakan: "Kepalaku mau ancur rek",
                  deskripsiKerusakan:
                      "Ayam ayam apa yang ayam cihuy anjay mabar",
                  upah: "Rp 50.120",
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 0,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: MaterialButton(
                      onPressed: () {},
                      color: const Color(0xff006646),
                      elevation: 10,
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
                          fontStyle: FontStyle.normal,
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
// Widget ini membungkus kodingan panjang Container tawaran user
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
    this.imagePath = "assets/images/LogoBulat.png",
    this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(5),
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                      child: Container(
                        height: 45,
                        width: 45,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          namaUser,
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            fontSize: 14,
                            color: Color(0xff000000),
                          ),
                        ),
                        Text(
                          jarak,
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                            fontSize: 10,
                            color: Color(0xff3c4941),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.all(0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: warnaContainerTipe,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    tipeKerusakan,
                    textAlign: TextAlign.start,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.normal,
                      fontSize: 10,
                      color: warnaTextTipe,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  judulKerusakan,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  deskripsiKerusakan,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.normal,
                    fontSize: 10,
                    color: Color(0xff3d4a42),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Text(
                        "Upah Tawaran",
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          fontSize: 10,
                          color: Color(0xff3e4c44),
                        ),
                      ),
                      Text(
                        upah,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          fontSize: 16,
                          color: Color(0xff006b4a),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onDetailTap,
                    child: Container(
                      margin: const EdgeInsets.all(0),
                      padding: const EdgeInsets.all(0),
                      width: 110,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xff006445),
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Detail Tawaran",
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.normal,
                            fontSize: 13,
                            color: Color(0xffffffff),
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
      ),
    );
  }
}
