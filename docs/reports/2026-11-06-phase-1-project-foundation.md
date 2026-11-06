# Implementation Report: Phase 1 — Project Foundation

- **Tanggal Pelaksanaan:** 2026-11-06
- **Status:** COMPLETED
- **Pelaksana:** Senior Godot Engineer & Technical Lead
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan seluruh fondasi teknis pada **Phase 1: Project Foundation & Core Architecture** untuk game *Petualang Untidar*. Pekerjaan mencakup standardisasi konfigurasi `project.godot` (display, pixel art snapping, texture filtering, orientation, input map, autoloads), pembentukan hierarki folder proyek, implementasi 4 sistem Autoload inti, implementasi 6 komponen modular dasar (FSM, Health, Velocity, Hitbox, Hurtbox), pembuatan Main Scene validasi, dan pengujian otomatis via headless test suite.

---

## 2. Objective

1. Menetapkan spesifikasi render pixel-perfect (`640x360`, `viewport` stretch mode, `Nearest` texture filtering, pixel snap).
2. Membangun Input Map standar yang mendukung 14 action (Movement, Action, Interface).
3. Membentuk struktur folder proyek yang rapi dan modular sesuai pedoman teknis.
4. Mengimplementasikan core Autoload (`EventBus`, `GameManager`, `AudioManager`, `SceneManager`) dengan static typing penuh.
5. Menyediakan komponen dasar reusable (`State`, `StateMachine`, `HealthComponent`, `VelocityComponent`, `HitboxComponent`, `HurtboxComponent`).
6. Membuat dan memverifikasi Main Scene (`main.tscn` & `main.gd`).
7. Memvalidasi sistem dengan automated test suite tanpa error/warning.

---

## 3. Files Created

| Path Berkas | Deskripsi / Peran |
| :--- | :--- |
| `scripts/autoload/event_bus.gd` | Global Signal Bus untuk komunikasi loosely-coupled antarmodul. |
| `scripts/autoload/game_manager.gd` | Pengelola state siklus game dan status pause. |
| `scripts/autoload/audio_manager.gd` | Pengelola BGM, pooling SFX, volume bus, dan Web Audio unlock. |
| `scripts/autoload/scene_manager.gd` | Pengelola transisi scene dan fade overlay. |
| `scripts/states/state.gd` | Kelas basis (`class_name State`) untuk seluruh node state FSM. |
| `scripts/states/state_machine.gd` | Pengendali FSM generic (`class_name StateMachine`). |
| `scripts/components/health_component.gd` | Komponen darah, damage intake, heal, dan sinyal kematian. |
| `scripts/components/velocity_component.gd` | Komponen kalkulasi fisika 2D (kecepatan, akselerasi, friksi). |
| `scripts/components/hitbox_component.gd` | Area2D pengirim damage dan knockback ke Hurtbox. |
| `scripts/components/hurtbox_component.gd` | Area2D penerima damage dengan i-frames terintegrasi ke Health. |
| `scenes/main/main.tscn` | Main Scene entry point untuk validasi fondasi proyek. |
| `scenes/main/main.gd` | Script pengontrol Main Scene dan monitor status Autoload/Input. |
| `tests/test_phase_1.gd` | Automated headless validation test suite (45 assertion tests). |

---

## 4. Files Modified / Deleted

| Path Berkas | Tindakan | Alasan |
| :--- | :---: | :--- |
| `project.godot` | MODIFIED | Penerapan display viewport 640x360, pixel snap, input map, dan registrasi autoloads. |
| `scripts/main.gd` | DELETED | Script template bawaan kosong dihapus dan digantikan oleh `scenes/main/main.gd`. |
| `scripts/main.gd.uid` | DELETED | UID dari template lama dihapus seiring pemindahan file script. |

---

## 5. Project Configuration Changes (`project.godot`)

Parameter berikut telah diverifikasi dan aktif di `project.godot`:

```ini
[application]
config/name="Petualang-Untidar"
run/main_scene="res://scenes/main/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]
EventBus="*res://scripts/autoload/event_bus.gd"
GameManager="*res://scripts/autoload/game_manager.gd"
AudioManager="*res://scripts/autoload/audio_manager.gd"
SceneManager="*res://scripts/autoload/scene_manager.gd"

[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/handheld/orientation=6 ; sensor_landscape

[rendering]
textures/canvas_textures/default_texture_filter=0 ; Nearest
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
```

### Input Map Terstandarisasi:
* **Movement:** `move_up` (W, Up), `move_down` (S, Down), `move_left` (A, Left), `move_right` (D, Right).
* **Action:** `interact` (E), `attack` (J, Mouse Left), `dodge` (Space), `skill_primary` (K), `skill_secondary` (L).
* **Interface:** `inventory` (I), `character` (C), `quest_log` (Q), `map` (M), `pause` (Escape).

---

## 6. Autoload Implementation

Semua singleton beroperasi dalam mode `PROCESS_MODE_ALWAYS` agar tetap responsif saat game di-pause:
1. **`EventBus`**: Memiliki sinyal terdefinisi untuk player stats, combat events, inventory/equipment, quest progress, dan game state.
2. **`GameManager`**: Mengelola enum `GameState` (`BOOT`, `MAIN_MENU`, `PLAYING`, `PAUSED`, `DIALOGUE`, `GAME_OVER`). Mengatur `get_tree().paused` secara aman.
3. **`AudioManager`**: Menyediakan 1 player BGM dengan tweening volume crossfade, 8 pool channel SFX, pengaturan volume bus desibel, dan kesiapan pembukaan audio lock web.
4. **`SceneManager`**: Mengelola transisi scene menggunakan CanvasLayer mandiri (Layer 100) dengan efek fade-to-black tanpa freeze.

---

## 7. Core Components Implementation

* **`State` & `StateMachine`**: Menggunakan pola FSM berbasis node. Telah dioptimasi agar aman diinisialisasi secara deklaratif maupun instansiasi via kode (`if owner: await owner.ready`).
* **`HealthComponent`**: Mencegah race-condition damage saat darah sudah 0, mendukung setter dinamis `max_health`, sinyal `health_changed`, `damage_taken`, `healed`, dan `died`.
* **`VelocityComponent`**: Menyediakan metode `accelerate_in_direction()`, `decelerate()`, `apply_to_body()`, dan `stop()` dengan pembatasan kecepatan maksimum.
* **`HitboxComponent` & `HurtboxComponent`**: Area2D yang terhubung secara modular. Hurtbox secara otomatis memicu timer invulnerability (i-frames) dan meneruskan nilai damage ke `HealthComponent`.

---

## 8. Main Scene Implementation

Scene `scenes/main/main.tscn` bertindak sebagai dashboard verifikasi:
* Menampilkan judul proyek dan subjudul Phase 1.
* Menguji ketersediaan keempat Autoload saat inisialisasi.
* Memicu transisi status GameManager dari `BOOT` ke `PLAYING`.
* Mendeteksi penekanan tombol Input Map dan menampilkan nama action aktif secara real-time.
* Menangani penekanan tombol `pause` (Escape) untuk menguji fungsionalitas pause/resume engine.

---

## 9. Testing & Validation

Pengujian dilakukan menggunakan CLI Godot Engine 4.7.2 resmi:

### A. Headless Engine Main Scene Run
* Perintah: `godot --headless --quit-after 30`
* Hasil: Main Scene berhasil di-mount, Autoloads terinisialisasi dengan urutan yang benar, state beralih ke `PLAYING`, dan engine keluar bersih dengan kode 0 (0 error, 0 warning).

### B. Automated Headless Test Suite (`tests/test_phase_1.gd`)
* Perintah: `godot --headless -s tests/test_phase_1.gd`
* Rincian Hasil Pengujian:
  1. Project Settings Validation (9 assertions): **PASS**
  2. Input Map Action Validation (14 assertions): **PASS**
  3. Autoload & State Transitions (8 assertions): **PASS**
  4. HealthComponent Logic & Signals (7 assertions): **PASS**
  5. VelocityComponent Physics (2 assertions): **PASS**
  6. Hitbox & Hurtbox Interaction (2 assertions): **PASS**
  7. StateMachine Transition & Events (3 assertions): **PASS**
* **Total Assertions:** 45 Passed, 0 Failed.

### C. Status Export Templates
* Lokasi `~/Library/Application Support/Godot/export_templates/` saat ini kosong (belum diunduh oleh user).
* Kesimpulan: Konfigurasi engine sudah 100% kompatibel dengan Web dan Android (`gl_compatibility`, aspect keep, sensor landscape, touch-ready input action mapping). Namun, build artifact Web/Android belum dieksekusi menunggu instalasi export template pada tahap selanjutnya.

---

## 10. Known Issues & Technical Risks

1. **GDScript Lambda Primitive Variable Scoping:**
   * *Temuan:* Variabel bertipe primitif (`bool`, `int`) di-capture by-value dalam lambda GDScript.
   * *Solusi yang Telah Diterapkan:* Menggunakan objek Dictionary (`flags["key"]`) pada pengujian signal testing.
2. **Export Templates Belum Terinstal:**
   * Diperlukan pengunduhan export templates Godot 4.7.2 sebelum melangkah ke rilis build Web/Android (direncanakan pada Phase 8).

---

## 11. Remaining Tasks

Seluruh tugas Phase 1 telah selesai secara menyeluruh. Tidak ada sisa pekerjaan tertunda untuk fondasi dasar.

---

## 12. Technical Decisions Adopted

* **ADR-007 (Status: ADOPTED):** Standar resolusi 640x360 16:9, viewport stretch mode, Nearest filtering, dan pixel snapping.
* **ADR-010 (Status: ADOPTED):** Struktur folder root modular langsung (`scenes/`, `scripts/`, `assets/`, `resources/`, `docs/`) menggantikan subfolder bersarang `src/` untuk menyederhanakan path referensi Godot `res://`.

---

## 13. Next Recommended Steps (Phase 2 Preview)

Dengan fondasi teknis yang telah stabil dan tervalidasi, proyek siap melangkah ke **Phase 2: Character Foundation**:
1. Pembuatan entitas pemain `scenes/player/player.tscn` berbasis `CharacterBody2D`.
2. Integrasi `ModularVisuals` (rigging 10 layer sprite pixel art tersinkronisasi 1 `AnimationPlayer`).
3. Implementasi 8-arah pergerakan menggunakan FSM (`PlayerIdleState`, `PlayerMoveState`, `PlayerRollState`).
4. Pembuatan virtual joystick sentuh responsif untuk kontrol Web & Android.

