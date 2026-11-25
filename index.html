<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>MySard Remote</title>
<link href="https://googleapis.com" rel="stylesheet">
<script src="https://gstatic.com"></script>
<script src="https://gstatic.com"></script>
<style>
  body { background:#0b0e17; color:#fff; font-family:'Cairo',sans-serif; margin:0; padding:20px; }
  .card { background:#151a28; border-radius:20px; padding:18px; margin-bottom:16px; border:1px solid #262f45; }
  h2 { margin:0 0 12px; color:#3b82f6; font-size:20px; text-align:center; }
  input { width:100%; padding:14px; border-radius:12px; border:1px solid #334155; background:#0f131f; color:#fff; font-size:18px; text-align:center; box-sizing:border-box; font-family:'Cairo'; }
  button { width:100%; padding:14px; border-radius:12px; border:none; background:#16a34a; color:#fff; font-size:18px; font-weight:800; margin-top:10px; cursor:pointer; font-family:'Cairo'; }
  label { display:flex; justify-content:space-between; margin:12px 0 6px; font-size:15px; color:#cbd5e1; }
  input[type="range"] { width:100%; accent-color:#3b82f6; }
  .colors { display:flex; gap:12px; justify-content:center; margin-top:10px; }
  .c-btn { width:40px; height:40px; border-radius:50%; border:2px solid #fff; cursor:pointer; }
  #status { text-align:center; color:#4ade80; font-size:14px; margin-top:8px; }
</style>
</head>
<body>

<div class="card" id="pinCard">
  <h2>🔗 أدخل الرمز الظاهر على التلفزيون</h2>
  <input type="tel" id="pinInput" maxlength="4" placeholder="مثلاً: 4829">
  <button style="background:#2563eb;" onclick="connectTV()">اتصال بالشاشة</button>
</div>

<div id="remoteArea" style="display:none;">
  <div class="card">
    <h2 id="titlePin">💬 التحكم المباشر</h2>
    <input type="text" id="subText" placeholder="اكتب أي جملة هنا..." oninput="sendUpdate()">
    <button onclick="sendUpdate()">إرسال النص الآن</button>
    <div id="status">متصل بسيرفر جوجل الرسمي ✅</div>
  </div>

  <div class="card">
    <h2>🎨 تخصيص المظهر لايف</h2>
    <label>حجم الخط <span id="sizeVal">36</span></label>
    <input type="range" id="fontSize" min="20" max="65" value="36" oninput="sendUpdate()">

    <label>ارتفاع الترجمة من الأسفل <span id="posVal">60</span></label>
    <input type="range" id="bottomPad" min="20" max="350" value="60" oninput="sendUpdate()">

    <label>شفافية الخلفية <span id="opVal">75%</span></label>
    <input type="range" id="bgOp" min="0" max="100" value="75" oninput="sendUpdate()">

    <label>لون النص</label>
    <div class="colors">
      <div class="c-btn" style="background:#FFFFFF" onclick="setColor('#FFFFFF')"></div>
      <div class="c-btn" style="background:#FACC15" onclick="setColor('#FACC15')"></div>
      <div class="c-btn" style="background:#38BDF8" onclick="setColor('#38BDF8')"></div>
      <div class="c-btn" style="background:#4ADE80" onclick="setColor('#4ADE80')"></div>
    </div>
  </div>
</div>

<script>
firebase.initializeApp({
  databaseURL: "https://firebaseio.com"
});
let dbRef = null;
let textColor = "#FFFFFF";

function connectTV() {
  const rawPin = document.getElementById("pinInput").value.trim()
    .replace(/[٠-٩]/g, d => "٠١٢٣٤٥٦٧٨٩".indexOf(d));
  if (rawPin.length < 4) return alert("أدخل 4 أرقام");
  dbRef = firebase.database().ref("sessions/" + rawPin);
  document.getElementById("pinCard").style.display = "none";
  document.getElementById("remoteArea").style.display = "block";
  document.getElementById("titlePin").innerText = "💬 التحكم بالشاشة (" + rawPin + ")";
  sendUpdate();
}

function setColor(hex) { textColor = hex; sendUpdate(); }

function sendUpdate() {
  if (!dbRef) return;
  const fontSize = Number(document.getElementById("fontSize").value);
  const bottomPadding = Number(document.getElementById("bottomPad").value);
  const bgOpacity = Number(document.getElementById("bgOp").value) / 100;
  const text = document.getElementById("subText").value || "تم الربط العشوائي بنجاح يا زياد!";

  document.getElementById("sizeVal").innerText = fontSize;
  document.getElementById("posVal").innerText = bottomPadding;
  document.getElementById("opVal").innerText = Math.round(bgOpacity*100) + "%";
  document.getElementById("status").innerText = "جاري الإرسال...";

  dbRef.set({ connected: true, text, fontSize, bottomPadding, bgOpacity, textColor })
    .then(() => {
      document.getElementById("status").innerText = "✅ تم الإرسال للشاشة بنجاح!";
    })
    .catch((err) => {
      document.getElementById("status").innerText = "❌ خطأ: " + err.message;
    });
}
</script>
</body>
</html>
