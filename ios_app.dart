import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MySardIOSApp());

class MySardIOSApp extends StatelessWidget {
  const MySardIOSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0B0E17)),
      home: const RemoteHomeScreen(),
    );
  }
}

class RemoteHomeScreen extends StatefulWidget {
  const RemoteHomeScreen({super.key});
  @override
  State<RemoteHomeScreen> createState() => _RemoteHomeScreenState();
}

class _RemoteHomeScreenState extends State<RemoteHomeScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  String? connectedPin;
  String status = "جاهز للإرسال ✅";
  double fontSize = 36.0;
  double bottomPadding = 60.0;
  double bgOpacity = 0.75;
  String textColor = "#FFFFFF";

  void _connect() {
    String raw = _pinCtrl.text.trim();
    const ar = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    for (int i = 0; i < 10; i++) {
      raw = raw.replaceAll(ar[i], i.toString());
    }
    if (raw.length < 4) return;
    setState(() => connectedPin = raw);
    _sendUpdate();
  }

  Future<void> _sendUpdate() async {
    if (connectedPin == null) return;
    setState(() => status = "جاري الإرسال...");
    try {
      final url = Uri.parse("https://ntfy.sh");
      final res = await http.post(
        url,
        body: jsonEncode({
          "text": _textCtrl.text.isEmpty ? "تم الربط من تطبيق الآيفون بنجاح!" : _textCtrl.text,
          "fontSize": fontSize,
          "bottomPadding": bottomPadding,
          "bgOpacity": bgOpacity,
          "textColor": textColor,
        }),
      );
      setState(() => status = res.statusCode == 200 ? "✅ تم الإرسال للشاشة بنجاح!" : "❌ خطأ: ${res.statusCode}");
    } catch (e) {
      setState(() => status = "❌ تعذر الاتصال: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("MySard Remote", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF151A28),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: connectedPin == null
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF151A28), borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      const Text("🔗 أدخل رمز التلفزيون", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "0000",
                          filled: true,
                          fillColor: const Color(0xFF0F131F),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          onPressed: _connect,
                          child: const Text("اتصال بالشاشة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF151A28), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        children: [
                          Text("💬 متصل بالشاشة ($connectedPin)", style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _textCtrl,
                            onChanged: (_) => _sendUpdate(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              hintText: "اكتب أي جملة لتظهر على التلفزيون...",
                              filled: true,
                              fillColor: const Color(0xFF0F131F),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: _sendUpdate,
                              child: const Text("إرسال النص الآن", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(status, style: const TextStyle(color: Colors.greenAccent, fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF151A28), borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(child: Text("🎨 تخصيص المظهر لايف", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                          const SizedBox(height: 12),
                          Text("حجم الخط: ${fontSize.toInt()}"),
                          Slider(value: fontSize, min: 20, max: 65, onChanged: (v) { setState(() => fontSize = v); _sendUpdate(); }),
                          Text("ارتفاع الترجمة: ${bottomPadding.toInt()}"),
                          Slider(value: bottomPadding, min: 20, max: 350, onChanged: (v) { setState(() => bottomPadding = v); _sendUpdate(); }),
                          Text("شفافية الخلفية: ${(bgOpacity * 100).toInt()}%"),
                          Slider(value: bgOpacity, min: 0, max: 1, onChanged: (v) { setState(() => bgOpacity = v); _sendUpdate(); }),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _colorCircle("#FFFFFF", Colors.white),
                              _colorCircle("#FACC15", Colors.amber),
                              _colorCircle("#38BDF8", Colors.lightBlueAccent),
                              _colorCircle("#4ADE80", Colors.greenAccent),
                            ],
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

  Widget _colorCircle(String hex, Color c) {
    return GestureDetector(
      onTap: () { setState(() => textColor = hex); _sendUpdate(); },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      ),
    );
  }
}
