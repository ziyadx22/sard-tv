import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() => runApp(const MySardTVApp());

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SubtitleOverlayWidget(),
  ));
}

class MySardTVApp extends StatelessWidget {
  const MySardTVApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0B0E17)),
      home: const TVSetupScreen(),
    );
  }
}

class TVSetupScreen extends StatefulWidget {
  const TVSetupScreen({super.key});
  @override
  State<TVSetupScreen> createState() => _TVSetupScreenState();
}

class _TVSetupScreenState extends State<TVSetupScreen> {
  String status = "اضغط الزر بالأسفل لتشغيل الترجمة فوق الألعاب";

  Future<void> _startOverlay() async {
    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
    }
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: "MySard TV",
      overlayContent: "الترجمة نشطة",
      flag: OverlayFlag.clickThrough,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
    );
    setState(() => status = "✅ الترجمة نشطة الآن! انتقل لمدخل البلايستيشن واستمتع");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: const Color(0xFF151A28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("MySard TV", style: GoogleFonts.cairo(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 12),
              Text("رمز الربط الثابت: 1122", style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _startOverlay,
                child: Text("تفعيل الظهور فوق البلايستيشن", style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Text(status, style: GoogleFonts.cairo(fontSize: 18, color: Colors.greenAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

class SubtitleOverlayWidget extends StatefulWidget {
  const SubtitleOverlayWidget({super.key});
  @override
  State<SubtitleOverlayWidget> createState() => _SubtitleOverlayWidgetState();
}

class _SubtitleOverlayWidgetState extends State<SubtitleOverlayWidget> {
  final String dbUrl = "https://firebaseio.com";
  String subtitleText = "تم الربط بنجاح! جاهز للترجمة";
  double fontSize = 34.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.75;
  Color textColor = Colors.white;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(Uri.parse(dbUrl));
      if (res.statusCode == 200 && res.body != "null") {
        final data = jsonDecode(res.body);
        setState(() {
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
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
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
