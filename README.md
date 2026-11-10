# S4 Fader Bridge

讓 **Native Instruments Traktor Kontrol S4 MK2** 在 **Native Mode** 下照常控制 Traktor，同時把四個 Channel Fader 和 Crossfader 轉成 MIDI CC，送到 Ableton Live（或任何 DAW）。

*Mirror the S4 MK2's channel faders and crossfader to a virtual MIDI port while the controller stays in Native Mode for Traktor. macOS only.*

## 為什麼需要

Traktor 用 External Mixing 模式分軌輸出（例如透過 GroundControl 把四個 Deck 分別錄進 Ableton）時，Traktor 的內部推桿會被停用。S4 的推桿因此失去作用，而把 S4 切到 MIDI Mode 又會讓 Native 控制全部失效。

## 運作原理

- S4 MK2 的控制資料走 USB HID 介面（VID `0x17CC` / PID `0x1310`），由 macOS 內建的 HID 驅動處理。
- NI 的 `NIHardwareAgent` 以**非獨佔**方式開啟這個介面，所以其他程式也能同時讀取。
- 本程式同樣以非獨佔方式（`kIOHIDOptionsTypeNone`）開啟，**只讀取，從不傳送任何資料到控制器**，Traktor 完全不受影響。
- 讀到的推桿數值會從虛擬 CoreMIDI 埠 **「S4 Fader Bridge」** 送出。
- 不需要 kext、DriverKit，也不用關閉 SIP。

## MIDI 對應

全部在 **MIDI 通道 16**：

| 控制項 | CC |
|---|---|
| Channel Fader A | 20 |
| Channel Fader B | 21 |
| Channel Fader C | 22 |
| Channel Fader D | 23 |
| Crossfader | 24 |

推桿的 12-bit 數值會換算成 0–127，並內建防抖。

## 編譯

需要 macOS 11 以上，以及 Xcode Command Line Tools（`xcode-select --install`）。

```bash
./build.sh
```

產出：
- `build/S4 Fader Bridge.app`：選單列 App，沒有 Dock 圖示，可以拖進「應用程式」資料夾。
- `build/s4bridge`：命令列版本。

## 使用

### 選單列 App

打開 `S4 Fader Bridge.app`，選單列會出現推桿圖示：
- 圖示正常顯示：已連接 S4 MK2。
- 圖示變灰：未連接。
- 點圖示可以查看狀態，或選「結束」。

### 命令列

```bash
build/s4bridge          # 送出 MIDI，並列出每個 CC
build/s4bridge --dump   # 除錯用：列出 HID Report 中有變化的 byte，不送 MIDI
```

### Ableton Live 設定

1. 設定 → Link/Tempo/MIDI → Input Ports 中的 **S4 Fader Bridge**：打開 **Remote**。
2. 按 Cmd+M 進入映射模式，點軌道音量，再推 S4 的推桿。
3. 再按一次 Cmd+M 離開映射模式。

## 建議開啟順序

1. 接上 S4 MK2。
2. 打開 **S4 Fader Bridge**。
3. 打開 Traktor。
4. 打開 Ableton Live。

Bridge 和 Traktor 誰先開都可以；Bridge 在 Ableton 之前開，Ableton 一啟動就能看到 MIDI 埠。S4 中途拔掉再插上會自動重新連接。

## 致謝

HID Report 的推桿位置參考自 [Mixxx](https://github.com/mixxxdj/mixxx) 的 `Traktor-Kontrol-S4-MK2-hid-scripts.js`，並已用實機確認。

本專案與 Native Instruments、Ableton 無關。
