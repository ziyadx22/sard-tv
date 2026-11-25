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
  late String sessionCode;
  String subtitleText = "أدخل الرمز في آيفونك للبدء...";
  double fontSize = 36.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.75;
  Color textColor = Colors.white;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    sessionCode = (1000 + Random().nextInt(9000)).toString();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(Uri.parse("https://ntfy.sh"));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final lines = res.body.trim().split('\n');
        final lastEvent = jsonDecode(lines.last);
        if (lastEvent["message"] != null) {
          final data = jsonDecode(lastEvent["message"]);
          setState(() {
            subtitleText = data["text"] ?? subtitleText;
            fontSize = (data["fontSize"] ?? 36.0).toDouble();
            bottomPadding = (data["bottomPadding"] ?? 60.0).toDouble();
            bgOpacity = (data["bgOpacity"] ?? 0.75).toDouble();
            String hex = (data["textColor"] ?? "#FFFFFF").replaceAll("#", "");
            if (hex.length == 6) textColor = Color(int.parse("FF$hex", radix: 16));
          });
        }
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
          Positioned(
            top: 28,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Text("رمز الربط: $sessionCode", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
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
