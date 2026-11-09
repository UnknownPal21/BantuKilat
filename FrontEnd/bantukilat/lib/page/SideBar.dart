///File download from FlutterViz- Drag and drop a tools. For more details visit https://flutterviz.io/

///File download from FlutterViz- Drag and drop a tools. For more details visit https://flutterviz.io/

import 'package:flutter/material.dart';

class SideBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0x00ffffff),
      body: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        width: 200,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Color(0xff006a49),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Color(0x4d9e9e9e), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(5, 30, 5, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                height: 60,
                width: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(shape: BoxShape.circle),
                child: Image.asset("assets/logo/LogoBulat.png", fit: BoxFit.cover),
              ),
              Padding(
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
                  color: Color(0xffffffff),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(vertical: 15, horizontal: 0),
                padding: EdgeInsets.zero,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Color(0x00000000),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
