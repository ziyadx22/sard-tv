import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() => runApp(const MySardTVApp());

class MySardTVApp extends StatelessWidget {
  const MySardTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
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
  final String dbUrl = "https://firebaseio.com";
  late String sessionCode;
  String subtitleText = "في انتظار بدء الترجمة من جوالك...";
  double fontSize = 34.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.75;
  Color textColor = Colors.white;
  bool isConnected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    sessionCode = (1000 + Random().nextInt(9000)).toString();
    _initSession();
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) => _fetchData());
  }

  Future<void> _initSession() async {
    await http.put(
      Uri.parse("$dbUrl/sessions/$sessionCode.json"),
      body: jsonEncode({
        "text": "تم الربط بنجاح! جرب تغيير الخط أو إرسال نص",
        "fontSize": 34.0,
        "bottomPadding": 60.0,
        "bgOpacity": 0.75,
        "textColor": "#FFFFFF",
        "connected": false
      }),
    );
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(Uri.parse("$dbUrl/sessions/$sessionCode.json"));
      if (res.statusCode == 200 && res.body != "null") {
        final data = jsonDecode(res.body);
        setState(() {
          isConnected = data["connected"] ?? false;
          subtitleText = data["text"] ?? subtitleText;
          fontSize = (data["fontSize"] ?? 34.0).toDouble();
          bottomPadding = (data["bottomPadding"] ?? 60.0).toDouble();
          bgOpacity = (data["bgOpacity"] ?? 0.75).toDouble();
          String hex = (data["textColor"] ?? "#FFFFFF").replaceAll("#", "");
          if (hex.length == 6) textColor = Color(int.parse("FF$hex", radix: 16));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!isConnected)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("MySard TV", style: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(data: sessionCode, size: 160),
                    ),
                    const SizedBox(height: 16),
                    Text("رمز الربط السريع: $sessionCode", style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    Text("أدخل هذا الرمز في صفحة التحكم على الآيفون", style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: bottomPadding,
            left: 40,
            right: 40,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(bgOpacity),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    shadows: [const Shadow(blurRadius: 6, color: Colors.black, offset: Offset(2, 2))],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
