/// Trang "Bật PC" mà trạm bật máy (điện thoại deck ở nhà) phục vụ ở
/// http://<địa chỉ Tailscale của trạm>:8788/.
///
/// Dành cho iPhone/iPad: bản web HeDeck do máy tính phục vụ nên máy tắt là mất
/// trang, còn trang này do điện thoại deck (luôn bật) phục vụ. Thêm vào Màn
/// hình chính là có nút "Bật PC".
///
/// Khoá ký lệnh nằm trong đường link, sau dấu # (…/#k=…): phần này không bao
/// giờ được trình duyệt gửi lên mạng, và iPhone giữ nguyên nó khi thêm vào
/// Màn hình chính (biểu tượng ngoài màn hình chính không dùng chung bộ nhớ
/// với Safari, nên không thể chỉ lưu khoá trong trình duyệt). Trang http không
/// có WebCrypto, nên HMAC-SHA256 viết tay bằng JavaScript bên dưới.
const wakePageHtml = r'''<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Bật PC">
<meta name="theme-color" content="#0F1218">
<link rel="apple-touch-icon" href="icon.png">
<link rel="icon" href="icon.png">
<title>Bật PC</title>
<style>
  html, body { margin: 0; height: 100%; background: #0F1218; color: #E8EAF0;
    font-family: -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { min-height: 100%; display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 22px; padding: 24px; box-sizing: border-box; text-align: center; }
  h1 { margin: 0; font-size: 22px; font-weight: 700; }
  p { margin: 0; color: #8A90A0; font-size: 15px; line-height: 1.5; max-width: 26em; }
  button { width: 170px; height: 170px; border-radius: 50%; border: 0; cursor: pointer;
    background: radial-gradient(circle at 35% 30%, #9488FF, #6A5CF0 60%, #4B3FD0);
    color: #fff; font: 700 19px -apple-system, "Segoe UI", Roboto, sans-serif;
    box-shadow: 0 18px 50px -12px rgba(123,110,246,.75); transition: transform .12s; }
  button:active { transform: scale(.95); }
  button:disabled { opacity: .55; }
  button svg { display: block; margin: 0 auto 6px; }
  #status { min-height: 3em; }
  .ok { color: #3FB27F !important; } .bad { color: #E0A030 !important; }
</style>
</head>
<body>
<main>
  <h1>HeDeck · Bật PC</h1>
  <button id="wake" type="button">
    <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4"
      stroke-linecap="round"><path d="M12 3v8"/><path d="M6.3 6.8a8 8 0 1 0 11.4 0"/></svg>
    Bật máy tính
  </button>
  <p id="status">Bật Tailscale trên iPhone trước khi bấm khi đang ở ngoài.</p>
  <p style="font-size:12px">Bấm Chia sẻ → Thêm vào Màn hình chính để có nút này ngoài màn hình chính.</p>
</main>
<script>
(function () {
  var K = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];

  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

  function sha256(bytes) {
    var H = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19];
    var len = bytes.length, n = ((len + 9 + 63) >> 6) << 6;
    var m = new Uint8Array(n); m.set(bytes); m[len] = 0x80;
    var dv = new DataView(m.buffer);
    dv.setUint32(n - 4, (len * 8) >>> 0);
    dv.setUint32(n - 8, Math.floor(len / 0x20000000));
    var w = new Array(64);
    for (var i = 0; i < n; i += 64) {
      for (var t = 0; t < 16; t++) w[t] = dv.getUint32(i + t * 4);
      for (t = 16; t < 64; t++) {
        var s0 = rotr(w[t-15], 7) ^ rotr(w[t-15], 18) ^ (w[t-15] >>> 3);
        var s1 = rotr(w[t-2], 17) ^ rotr(w[t-2], 19) ^ (w[t-2] >>> 10);
        w[t] = (w[t-16] + s0 + w[t-7] + s1) | 0;
      }
      var a = H[0], b = H[1], c = H[2], d = H[3], e = H[4], f = H[5], g = H[6], h = H[7];
      for (t = 0; t < 64; t++) {
        var t1 = (h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K[t] + w[t]) | 0;
        var t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
        h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      H[0] = (H[0] + a) | 0; H[1] = (H[1] + b) | 0; H[2] = (H[2] + c) | 0; H[3] = (H[3] + d) | 0;
      H[4] = (H[4] + e) | 0; H[5] = (H[5] + f) | 0; H[6] = (H[6] + g) | 0; H[7] = (H[7] + h) | 0;
    }
    var out = new Uint8Array(32), ov = new DataView(out.buffer);
    for (i = 0; i < 8; i++) ov.setUint32(i * 4, H[i] >>> 0);
    return out;
  }

  function concat(a, b) { var r = new Uint8Array(a.length + b.length); r.set(a); r.set(b, a.length); return r; }

  function hmac(key, msg) {
    if (key.length > 64) key = sha256(key);
    var k = new Uint8Array(64); k.set(key);
    var ipad = new Uint8Array(64), opad = new Uint8Array(64);
    for (var i = 0; i < 64; i++) { ipad[i] = k[i] ^ 0x36; opad[i] = k[i] ^ 0x5c; }
    return sha256(concat(opad, sha256(concat(ipad, msg))));
  }

  function fromB64(s) { var b = atob(s), r = new Uint8Array(b.length);
    for (var i = 0; i < b.length; i++) r[i] = b.charCodeAt(i); return r; }
  function toB64(u) { var s = ""; for (var i = 0; i < u.length; i++) s += String.fromCharCode(u[i]); return btoa(s); }
  function utf8(s) { return new TextEncoder().encode(s); }

  window.hedeckHmac = function (keyB64, text) { return toB64(hmac(fromB64(keyB64), utf8(text))); };

  var status = document.getElementById("status");
  var button = document.getElementById("wake");
  function say(text, cls) { status.textContent = text; status.className = cls || ""; }

  var m = location.hash.match(/k=([^&]+)/);
  var key = m ? decodeURIComponent(m[1]) : "";
  if (!key) {
    button.disabled = true;
    say("Trang này cần mở từ HeDeck: trên iPhone mở HeDeck khi máy tính đang bật → ⚙ → Nút bật máy cho iPhone.", "bad");
    return;
  }

  button.addEventListener("click", function () {
    button.disabled = true;
    say("Đang gửi…");
    var ts = Math.floor(Date.now() / 1000);
    var rnd = new Uint8Array(12); crypto.getRandomValues(rnd);
    var nonce = Array.prototype.map.call(rnd, function (x) { return ("0" + x.toString(16)).slice(-2); }).join("");
    var sig;
    try { sig = window.hedeckHmac(key, "wake|" + ts + "|" + nonce); }
    catch (e) { say("Đường link bị hỏng — tạo lại nút từ HeDeck (⚙ → Nút bật máy cho iPhone).", "bad"); button.disabled = false; return; }
    fetch("wake", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ts: ts, nonce: nonce, sig: sig }) })
      .then(function (r) { return r.json().then(function (j) { return [r.status, j]; }); })
      .then(function (res) {
        var j = res[1];
        if (res[0] === 200 && j.away) say("Điện thoại deck đang không ở nhà (nối mạng khác) nên không bật được máy. Để điện thoại deck ở nhà, nối Wi-Fi nhà.", "bad");
        else if (res[0] === 200 && j.ok) say("Đã gửi tín hiệu bật máy. Windows cần khoảng 20–60 giây để lên.", "ok");
        else if (res[0] === 403 && j.error === "bad_signature")
          say("Khoá không khớp (có thể máy tính đã cấp khoá mới). Tạo lại nút từ HeDeck: ⚙ → Nút bật máy cho iPhone. Nếu giờ iPhone sai lệch nhiều, chỉnh lại giờ tự động.", "bad");
        else if (res[0] === 200) say("Điện thoại deck chưa có địa chỉ MAC của máy tính — mở HeDeck trên điện thoại deck khi máy tính đang bật một lần.", "bad");
        else say("Trạm báo lỗi (" + res[0] + "). Thử lại sau.", "bad");
      })
      .catch(function () {
        say("Không tới được điện thoại deck — iPhone đã bật Tailscale chưa? Điện thoại deck có đang mở HeDeck không?", "bad");
      })
      .then(function () { setTimeout(function () { button.disabled = false; }, 1500); });
  });
})();
</script>
</body>
</html>
''';
