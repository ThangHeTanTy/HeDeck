"""Âm lượng riêng của từng ứng dụng trên Windows.

Windows quản lý âm thanh theo "phiên" (audio session): mỗi tiến trình phát
tiếng có một phiên riêng, chỉnh được độc lập với âm lượng chung. Đây là thứ
làm nên khác biệt cho một deck livestream — hạ nhạc nền mà không hạ giọng nói.

Dùng pycaw. Thiếu thư viện thì các hàm ở đây trả về None, agent sẽ báo lỗi
gọn gàng thay vì sập.
"""

import os

STEP = 0.05          # mỗi lần bấm đổi 5%
_UNAVAILABLE = "Thiếu thư viện pycaw. Chạy: pip install -r requirements.txt"


def available():
    try:
        from pycaw.pycaw import AudioUtilities  # noqa: F401
        return True
    except Exception:
        return False


def _sessions_for(exe_name):
    """Mọi phiên âm thanh thuộc về tiến trình có tên exe_name."""
    from pycaw.pycaw import AudioUtilities

    target = os.path.basename(exe_name).lower()
    found = []
    for session in AudioUtilities.GetAllSessions():
        try:
            if session.Process and session.Process.name().lower() == target:
                found.append(session)
        except Exception:
            continue
    return found


def _volume_interface(session):
    from ctypes import cast, POINTER
    from comtypes import CLSCTX_ALL  # noqa: F401
    from pycaw.pycaw import ISimpleAudioVolume

    return cast(session._ctl.QueryInterface(ISimpleAudioVolume),
                POINTER(ISimpleAudioVolume))


def get_state(exe_name):
    """Trả về (âm_lượng 0..1, đang_tắt_tiếng) hoặc None nếu app không phát."""
    if not available():
        return None
    try:
        import pythoncom
        pythoncom.CoInitialize()
    except Exception:
        pass

    try:
        sessions = _sessions_for(exe_name)
        if not sessions:
            return None
        vol = _volume_interface(sessions[0])
        return float(vol.GetMasterVolume()), bool(vol.GetMute())
    except Exception:
        return None


def apply(exe_name, action, step=STEP):
    """Chỉnh âm lượng của một app.

    action: 'up' | 'down' | 'mute' | 'set'
    Trả về (ok, thông_điệp, âm_lượng_mới, đang_tắt_tiếng).
    """
    if not available():
        return False, _UNAVAILABLE, None, None

    try:
        import pythoncom
        pythoncom.CoInitialize()
    except Exception:
        pass

    try:
        sessions = _sessions_for(exe_name)
        if not sessions:
            return False, f"{exe_name} hiện không phát âm thanh", None, None

        level = muted = None
        for session in sessions:
            vol = _volume_interface(session)
            current = vol.GetMasterVolume()

            if action == "up":
                level = min(1.0, current + step)
                vol.SetMasterVolume(level, None)
                # Tăng tiếng thì bỏ tắt tiếng luôn, đó là điều người dùng muốn.
                vol.SetMute(0, None)
                muted = False
            elif action == "down":
                level = max(0.0, current - step)
                vol.SetMasterVolume(level, None)
                muted = bool(vol.GetMute())
            elif action == "mute":
                muted = not bool(vol.GetMute())
                vol.SetMute(1 if muted else 0, None)
                level = current
            else:
                return False, f"Hành động lạ: {action}", None, None

        return True, "", level, muted
    except Exception as exc:
        return False, f"Không chỉnh được âm lượng: {exc}", None, None
