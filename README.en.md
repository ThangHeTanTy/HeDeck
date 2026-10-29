<div align="center">

<img src="docs/images/logo-small.png" width="120" alt="HeDeck">

# HeDeck

**Turn a spare Android phone into a Stream Deck for your Windows PC.**

Tap a tile and an app opens on your computer and jumps to the front. Plus media
controls, per-app volume, keyboard macros, a touchpad and a gaming performance
overlay — no dedicated hardware to buy.

[🇻🇳 Tiếng Việt](README.md) · **🇬🇧 English**

<a href="https://thanghetanty.github.io/HeDeck/"><img src="https://img.shields.io/badge/Download-HeDeck%20website-7B6EF6?style=for-the-badge" alt="HeDeck download page"></a>
<a href="https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeckAgent.zip"><img src="https://img.shields.io/badge/Windows%2010%2F11-HeDeckAgent.zip-0078D4?style=for-the-badge" alt="Download for Windows"></a>
<a href="https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeck.apk"><img src="https://img.shields.io/badge/Android%207%2B-HeDeck.apk-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download for Android"></a>

<a href="https://github.com/ThangHeTanTy/HeDeck/releases/latest"><img src="https://img.shields.io/github/v/release/ThangHeTanTy/HeDeck?label=version&color=7B6EF6" alt="Latest version"></a>
<a href="https://github.com/ThangHeTanTy/HeDeck/releases"><img src="https://img.shields.io/github/downloads/ThangHeTanTy/HeDeck/total?label=downloads&color=3FB27F" alt="Downloads"></a>
<a href="https://github.com/ThangHeTanTy/HeDeck/stargazers"><img src="https://img.shields.io/github/stars/ThangHeTanTy/HeDeck?style=flat&label=stars&color=E0A030" alt="GitHub stars"></a>

<img src="docs/images/deck-5x2.png" width="620" alt="HeDeck on a phone">

</div>

---

## What it does

| | |
|---|---|
| **Open and switch apps** | Tap a tile to open an app and bring it to the front. Tap again to minimise, hold for 3 seconds to close it. |
| **Pick a window** | Three Chrome windows open? The tile shows 1, 2, 3 above the icon — tap a number to jump to that window, like the Windows taskbar. |
| **Automatic pages** | Like a Stream Deck profile: launch a game and the deck switches to your Game page; back on the desktop, back to Work. |
| **Touchpad and keyboard** | Move the mouse, scroll, drag and type (including Vietnamese) remotely. |
| **Performance overlay** | FPS, 1% low, CPU/GPU temperature and load, VRAM, RAM, network — on the phone, not over your game. |
| **Scenes** | One tap opens and closes several apps: "Gaming" opens Discord and your game, closes Chrome. |
| **Keyboard macros** | A tile types `ctrl+shift+p`, or a whole multi-step sequence. |
| **Per-app volume** | Turn down background music without turning down voices. |
| **Two-state tiles** | Tap on, tap off. Each side has its own icon and colour, so you can see from across the room whether the mic is muted. |
| **Media controls** | A fixed bar at the bottom of the screen, using no tiles. |
| **Remote power** | Wake the PC even after a full shutdown (Wake-on-LAN). While it runs: lock, sleep, restart, shut down. |
| **Light / dark, Vietnamese / English** | Switch in the gear menu. The first launch follows the phone's language. |
| **Self-updating** | The app and the agent tell you when a new version is out. Updating keeps all your pages, tiles and settings. |

---

## How it works

```
   Android phone                 Same Wi-Fi network            Windows PC
  ┌──────────────────┐                                    ┌──────────────────┐
  │   HeDeck (app)   │ ──── WebSocket ws://<ip>:8787 ────▶│  HeDeck Agent    │
  │  tiles, macros   │                                    │  opens apps,     │
  │  media, volume   │ ◀─── status every 1.5 seconds ─────│  focuses windows │
  └──────────────────┘                                    └──────────────────┘
```

You need **both parts**: the app on your phone and the agent on your PC. A phone
cannot open apps on a computer by itself, so the agent is required.

Everything stays on your home network. There is no account and no cloud
service; the agent only accepts devices on your local network, and every
command is signed with the phone's Ed25519 key, set up when you pair.

---

## Install

You need Windows 10 or 11, Android 7.0 or later, and both devices on the same
Wi-Fi. Nothing else to install.

<img src="docs/images/qr-tai-hedeck.png" width="160" align="right" alt="QR code to the download page">

**1. PC — the agent**

Download [`HeDeckAgent.zip`](https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeckAgent.zip),
unzip it to a permanent folder (for example `C:\HeDeck`) and double-click
`HeDeckAgent.exe`.

- If Windows SmartScreen says *"Windows protected your PC"*, click
  **More info → Run anyway**. The file is not signed with a paid certificate;
  it is built by GitHub from the public source in this repository.
- When Windows Firewall asks, allow access on **Private networks**.

**2. Phone — the app**

Scan the QR code, or open
[`HeDeck.apk`](https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeck.apk)
on the phone. Allow your browser to install apps when Android asks; if Play
Protect warns about an unknown app, choose **Install anyway**.

**3. Pair**

Open the app, pick your PC (or type the IP address shown by the agent) and enter
the 6-digit code from the agent window. The code expires after 5 minutes — click
**Mã mới** (*new code*) in the agent window to get another. After pairing, the phone
reconnects by itself, even if the router gives the PC a new IP.

### The agent runs in the background

Clicking **X** on the agent window only hides it. The agent keeps running in the
system tray (the **^** arrow at the right of the taskbar), so it never takes up
space while you work:

- **Click** the HeDeck icon to show the window again.
- **Right-click** it for **Mã ghép cặp mới** (*new pairing code*) or
  **Thoát HeDeck Agent** (*quit*). Quitting from here is the only way to stop
  the agent.
- Starting `HeDeckAgent.exe` again while it runs just brings the window back.

`TU_CHAY_CUNG_WINDOWS.bat` in the same folder starts the agent hidden in the tray
every time you sign in to Windows (run it again to undo).
`CAI_BAT_MAY_TU_XA.bat` sets up Wake-on-LAN; see
[docs/BAT_MAY_TU_XA.md](docs/BAT_MAY_TU_XA.md) (Vietnamese) for the BIOS side.

---

## Updates

Nothing is ever installed behind your back — both parts ask first.

- **App:** gear ⚙ → **Check for updates**. The app shows what changed, downloads
  the new version and opens Android's installer; tap **Install**. Your pages,
  tiles, settings and pairing are kept.
- **Agent:** it checks GitHub at start-up and every 12 hours. When a new version
  is out, the tray shows a notification and the agent window shows
  **Xem và cập nhật** (*view and update*). Confirm, and the agent downloads it, verifies its SHA-256,
  replaces itself and restarts.

> The interface text in the agent window and some documents are in Vietnamese
> only for now. The phone app is fully available in English.

---

## Building from source

The full developer guide is in Vietnamese: [README.md](README.md),
[docs/KY_THUAT.md](docs/KY_THUAT.md) (architecture and protocol) and
[docs/PHAT_HANH.md](docs/PHAT_HANH.md) (release process). In short:

- **Agent:** Python 3.10+ on Windows — run `agent\run_agent.bat`.
- **App:** Flutter SDK and Android Studio — run `setup_app.bat` once, then
  `CHAY_APP.bat` (debug on a USB-connected phone) or `BUILD_APK.bat`.
- **Releases:** pushing a `v1.2.3` tag makes GitHub Actions build the APK and the
  agent and publish them as a GitHub Release (`PHAT_HANH.bat` does this for you).

Issues and pull requests are welcome.

---

## Author

**Hề IT** — the name HeDeck combines **Hề** (Vietnamese for "clown") and
**Deck**, hence the clown logo.

If HeDeck saves you from buying a Stream Deck, a ⭐ on GitHub keeps the project
going.
