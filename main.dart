import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MySardTVApp());

class MySardTVApp extends StatelessWidget {
  const MySardTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF070A12)),
      home: const TVScreen(),
    );
  }
}

class TVScreen extends StatefulWidget {
  const TVScreen({super.key});
  @override
  State<TVScreen> createState() => _TVScreenState();
}

class _TVScreenState extends State<TVScreen> {
  late String sessionCode;
  String subtitleText = "بانتظار الاتصال من الآيفون...";
  String connectionStatus = "جاهز للربط";
  bool isConnected = false;
  double fontSize = 38.0;
  double bottomPadding = 65.0;
  double bgOpacity = 0.80;
  Color textColor = Colors.white;
  Timer? _timer;
  String lastId = "";

  @override
  void initState() {
    super.initState();
    sessionCode = (1000 + Random().nextInt(9000)).toString();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(
        Uri.parse("https://ntfy.sh"),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        if (!isConnected) {
          setState(() => connectionStatus = "متصل بالسيرفر ✅");
        }
        if (res.body.trim().isNotEmpty) {
          final lines = res.body.trim().split('\n');
          for (var line in lines.reversed) {
            final ev = jsonDecode(line);
            if (ev["event"] == "message" && ev["message"] != null && ev["id"] != lastId) {
              lastId = ev["id"];
              final decodedStr = utf8.decode(base64Url.decode(ev["message"]));
              final data = jsonDecode(decodedStr);
              setState(() {
                isConnected = true;
                connectionStatus = "متصل بالآيفون 🟢";
                subtitleText = data["text"] ?? subtitleText;
                fontSize = (data["fontSize"] ?? 38.0).toDouble();
                bottomPadding = (data["bottomPadding"] ?? 65.0).toDouble();
                bgOpacity = (data["bgOpacity"] ?? 0.80).toDouble();
                String hex = (data["textColor"] ?? "#FFFFFF").replaceAll("#", "");
                if (hex.length == 6) textColor = Color(int.parse("FF$hex", radix: 16));
              });
              break;
            }
          }
        }
      }
    } catch (_) {
      setState(() => connectionStatus = "تحقق من الإنترنت ⚠️");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF10182B), Color(0xFF06080F)],
          ),
        ),
        child: Stack(
          children: [
            // الشريط العلوي: الشعار + رمز الربط + حالة الاتصال
            Positioned(
              top: 32,
              left: 40,
              right: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // شعار التطبيق
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.subtitles_rounded, color: Colors.blueAccent, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "MySard TV",
                        style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),

                  // بطاقة رمز الربط وحالة الاتصال
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F36),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12)],
                    ),
                    child: Row(
                      children: [
                        Text(
                          connectionStatus,
                          style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70),
                        ),
                        Container(
                          height: 24,
                          width: 1.5,
                          color: Colors.white24,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Text(
                          "رمز الربط: ",
                          style: GoogleFonts.cairo(fontSize: 20, color: Colors.white),
                        ),
                        Text(
                          sessionCode,
                          style: GoogleFonts.cairo(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // صندوق الترجمة السينمائي في الأسفل
            Positioned(
              bottom: bottomPadding,
              left: 50,
              right: 50,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(bgOpacity),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20)],
                  ),
                  child: Text(
                    subtitleText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.4,
                      shadows: [const Shadow(blurRadius: 8, color: Colors.black, offset: Offset(2, 2))],
                    ),
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
