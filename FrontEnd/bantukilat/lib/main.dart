import 'package:bantukilat/page/loginpage.dart';
import 'package:bantukilat/page/splash_screen.dart';
import 'package:bantukilat/page/teknisi/HomePageTeknisi.dart';
import 'package:bantukilat/page/user/HomePageUser.dart';
import 'package:bantukilat/services/auth_service.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: AuthService.validateSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          final Widget nextScreen = user == null
              ? const LoginPage()
              : ((user['role'] as String).toUpperCase() == 'TECHNICIAN'
                  ? const HomePageTeknisi()
                  : const HomePageUser());
          return SplashScreen(nextScreen: nextScreen);
        },
      ),
    );
  }
}

