import 'package:bantukilat/page/registerpage.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(
    text: "",
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Image(
                        image: AssetImage("assets/logo/LogoBulat.png"),
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Text(
                    "Lupa Password",
                    textAlign: TextAlign.start,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      fontSize: 25,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                    child: Text(
                      "Masukkan email untuk reset password.",
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        fontSize: 12,
                        color: Color(0xff414f47),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 0, 5),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Email",
                                textAlign: TextAlign.start,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 14,
                                  color: Color(0xff3e4c43),
                                ),
                              ),
                            ),
                          ),
                          TextField(
                            controller: _emailController,
                            obscureText: false,
                            keyboardType: TextInputType.emailAddress,
                            textAlign: TextAlign.start,
                            maxLines: 1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              fontSize: 14,
                              color: Color(0xff3b4840),
                            ),
                            decoration: InputDecoration(
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff3d4a42),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff3d4a42),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(0, 61, 74, 66),
                                  width: 1,
                                ),
                              ),
                              hintText: "user@gmail.com",
                              hintStyle: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                fontSize: 14,
                                color: Color.fromARGB(255, 170, 183, 175),
                              ),
                              filled: true,
                              fillColor: const Color(0xfff3f4ff),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              prefixIcon: const Icon(
                                Icons.mail,
                                color: Color(0xff3f4d45),
                                size: 24,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 30, 0, 15),
                            child: MaterialButton(
                              onPressed: () {},
                              color: const Color(0xff006747),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              padding: const EdgeInsets.all(16),
                              textColor: const Color(0xffffffff),
                              height: 50,
                              minWidth: MediaQuery.of(context).size.width,
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Text(
                                "Belum punya akun?",
                                textAlign: TextAlign.start,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 12,
                                  color: Color(0xff000000),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  " Daftar akun baru disini",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 12,
                                    color: Color(0xff006a49),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                const Text(
                                  "Daftar sebagai teknisi?",
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 12,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // Navigasi ke halaman Register Teknisi
                                  },
                                  child: const Text(
                                    " Daftar teknisi disini",
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.normal,
                                      fontSize: 12,
                                      color: Color(0xff006848),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
