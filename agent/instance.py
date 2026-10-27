"""Chỉ cho một agent chạy mỗi lúc.

Agent chạy ngầm ở khay hệ thống nên người dùng dễ mở thêm lần nữa mà không
biết bản cũ vẫn chạy. Lần mở thứ hai không chạy agent mới — nó nhờ bản đang
chạy hiện cửa sổ lên rồi thoát.

Dùng mutex và event có tên của Windows, gọi qua ctypes cho khỏi phụ thuộc
cách pywin32 đặt tên hằng số.
"""

import ctypes
import sys
import threading

_MUTEX = "Local\\HeDeckAgent"
_SHOW = "Local\\HeDeckAgentShow"

_WAIT_OBJECT_0 = 0x0
_WAIT_ABANDONED = 0x80
_INFINITE = 0xFFFFFFFF
_EVENT_MODIFY_STATE = 0x0002

_held = []  # giữ handle sống tới khi tiến trình thoát

if sys.platform == "win32":
    from ctypes import wintypes

    _k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _k32.CreateMutexW.restype = wintypes.HANDLE
    _k32.CreateMutexW.argtypes = (wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR)
    _k32.CreateEventW.restype = wintypes.HANDLE
    _k32.CreateEventW.argtypes = (wintypes.LPVOID, wintypes.BOOL, wintypes.BOOL,
                                  wintypes.LPCWSTR)
    _k32.OpenEventW.restype = wintypes.HANDLE
    _k32.OpenEventW.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR)
    _k32.SetEvent.argtypes = (wintypes.HANDLE,)
    _k32.CloseHandle.argtypes = (wintypes.HANDLE,)
    _k32.WaitForSingleObject.restype = wintypes.DWORD
    _k32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)


def acquire(wait_seconds=0):
    """Giành quyền chạy. False nếu đã có agent khác đang chạy.

    Sau khi tự cập nhật, bản mới chờ vài giây cho bản cũ thoát hẳn.
    """
    if sys.platform != "win32":
        return True
    handle = _k32.CreateMutexW(None, False, _MUTEX)
    if not handle:
        return True  # không tạo được mutex thì thôi, đừng chặn agent
    result = _k32.WaitForSingleObject(handle, int(wait_seconds * 1000))
    if result in (_WAIT_OBJECT_0, _WAIT_ABANDONED):
        _held.append(handle)
        return True
    _k32.CloseHandle(handle)
    return False


def ask_running_to_show():
    """Nhờ agent đang chạy hiện cửa sổ lên."""
    if sys.platform != "win32":
        return
    handle = _k32.OpenEventW(_EVENT_MODIFY_STATE, False, _SHOW)
    if handle:
        _k32.SetEvent(handle)
        _k32.CloseHandle(handle)


def on_show_request(callback):
    """Gọi callback (ở luồng riêng) mỗi khi lần mở thứ hai nhờ hiện cửa sổ."""
    if sys.platform != "win32":
        return
    handle = _k32.CreateEventW(None, False, False, _SHOW)
    if not handle:
        return
    _held.append(handle)

    def wait():
        while _k32.WaitForSingleObject(handle, _INFINITE) == _WAIT_OBJECT_0:
            callback()

    threading.Thread(target=wait, daemon=True, name="hedeck-show").start()
