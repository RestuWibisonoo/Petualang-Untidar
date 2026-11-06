# Implementation Report: Phase 2 — Character Foundation

- **Tanggal Pelaksanaan:** 2026-11-06
- **Status:** COMPLETED
- **Pelaksana:** Senior Godot Engineer, Gameplay Programmer & Technical Lead
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan seluruh fondasi karakter utama pada **Phase 2: Character Foundation** untuk game *Petualang Untidar*. Pekerjaan mencakup pembangunan scene pemain `player.tscn` berbasis `CharacterBody2D`, integrasi sistem pergerakan 8-arah dengan `VelocityComponent`, sistem Finite State Machine (Idle, Move, Roll), sistem kustomisasi modular 10 layer (`ModularVisuals`), sinkronisasi animasi via master `AnimationPlayer`, sistem kamera pixel-perfect `Camera2D`, sistem kontrol sentuh (`TouchVirtualJoystick` dan `TouchControls`), pembuatan aset placeholder prosedural, integrasi ke `main.tscn`, serta validasi menyeluruh melalui automated test suite.

---

## 2. Objective

1. Membangun scene karakter modular `scenes/player/player.tscn` dengan pemisahan tanggung jawab yang tegas.
2. Mengimplementasikan pergerakan 8 arah yang ternormalisasi (mencegah kecepatan diagonal berlebih).
3. Mengimplementasikan FSM berbasis node: `PlayerIdleState`, `PlayerMoveState`, dan `PlayerRollState`.
4. Membangun sistem `ModularVisuals` 10 layer (`AccessoryBack`, `Body`, `Legwear`, `Clothing`, `Armor`, `Headgear`, `Hair`, `AccessoryFront`, `Weapon`, `Effects`).
5. Menyediakan 12 animasi inti (`idle_*`, `walk_*`, `roll_*`) yang mengendalikan seluruh layer secara sinkron.
6. Memasang `Camera2D` dengan position smoothing yang halus untuk pixel art.
7. Membangun `TouchVirtualJoystick` dan tombol sentuh dodge untuk Android dan Web Touch.
8. Memvalidasi sistem dengan automated test suite (73 assertion tests Phase 2 + 45 assertion tests Phase 1 tanpa regresi).

---

## 3. Files Created & Modified

### A. File Baru Dibuat
* `scenes/player/player.tscn`: Scene karakter pemain utama lengkap.
* `scripts/player/player.gd`: Script controller entitas Player (`class_name Player`).
* `scripts/player/modular_visuals.gd`: Script pengontrol 10 layer modular sprite (`class_name ModularVisuals`).
* `scripts/player/states/player_idle_state.gd`: State Idle pemain (`class_name PlayerIdleState`).
* `scripts/player/states/player_move_state.gd`: State Move pemain (`class_name PlayerMoveState`).
* `scripts/player/states/player_roll_state.gd`: State Roll/Dodge pemain (`class_name PlayerRollState`).
* `scripts/ui/touch/virtual_joystick.gd`: Komponen joystick analog virtual (`class_name TouchVirtualJoystick`).
* `scripts/ui/touch/touch_controls.gd`: HUD sentuh mobile/web (`class_name TouchControls`).
* `scenes/ui/touch_controls.tscn`: Scene kontrol sentuh dengan joystick dan tombol dodge.
* `assets/characters/placeholder/*.png`: 10 berkas spritesheet placeholder 128x128 (4x4 frame 32x32).
* `docs/art/character-asset-standard.md`: Dokumen standar aset pixel art karakter.
* `tests/test_phase_2.gd`: Automated test suite untuk Phase 2 (73 assertions).

### B. File yang Dimodifikasi
* `scenes/main/main.tscn`: Diperbarui menjadi arena pengujian dengan instansiasi Player, TestArena, dan TouchControls.
* `scenes/main/main.gd`: Menghubungkan Player dengan HUD diagnostik (State, Speed, Facing) dan TouchControls.
* `scripts/components/velocity_component.gd`: Ditambahkan pembatasan `limit_length(max_speed)` untuk mencegah floating point overshoot.
* `scripts/states/state_machine.gd`: `get_current_state_name()` dinormalisasi menjadi lowercase StringName.
* `docs/development/roadmap.md`: Status Phase 2 diperbarui ke `COMPLETED`.
* `docs/decisions/technical-decisions.md`: Ditambahkan catatan ADR-011 dan ADR-012.

---

## 4. Player Scene Architecture (`player.tscn`)

Struktur hierarki node pada `scenes/player/player.tscn`:

```text
Player (CharacterBody2D) [Script: player.gd]
├── CollisionShape2D (CircleShape2D radius 6px di area kaki: pos (0, 8))
├── ModularVisuals (Node2D) [Script: modular_visuals.gd]
│   ├── AccessoryBack (Sprite2D - hframes:4, vframes:4)
│   ├── Body (Sprite2D - hframes:4, vframes:4)
│   ├── Legwear (Sprite2D - hframes:4, vframes:4)
│   ├── Clothing (Sprite2D - hframes:4, vframes:4)
│   ├── Armor (Sprite2D - hframes:4, vframes:4)
│   ├── Headgear (Sprite2D - hframes:4, vframes:4)
│   ├── Hair (Sprite2D - hframes:4, vframes:4)
│   ├── AccessoryFront (Sprite2D - hframes:4, vframes:4)
│   ├── Weapon (Sprite2D - hframes:4, vframes:4)
│   └── Effects (Sprite2D - hframes:4, vframes:4)
├── AnimationPlayer (12 animasi tersinkronisasi)
├── StateMachine (Node) [Script: state_machine.gd]
│   ├── Idle (Node) [Script: player_idle_state.gd]
│   ├── Move (Node) [Script: player_move_state.gd]
│   └── Roll (Node) [Script: player_roll_state.gd]
├── HealthComponent (Node) [Script: health_component.gd]
├── VelocityComponent (Node) [Script: velocity_component.gd]
└── Camera2D (Position Smoothing 8.0)
```

---

## 5. Movement & FSM Implementation

1. **8-Directional Vector:**
   * Dibaca menggunakan `Input.get_vector("move_left", "move_right", "move_up", "move_down")`.
   * Jika tidak ada input fisik, sistem memeriksa `touch_input_direction` dari Virtual Joystick.
   * Vektor ternormalisasi otomatis sehingga pergerakan diagonal memiliki kecepatan yang sama persis dengan pergerakan kardinal ($120.0 \text{ px/s}$).
2. **State Transitions:**
   * **`Idle`**: Aktif saat input nol. Memperlambat karakter via `velocity_component.decelerate(delta)`. Beralih ke `Move` jika ada input, atau ke `Roll` jika aksi `dodge` ditekan.
   * **`Move`**: Berjalan ke arah input via `velocity_component.accelerate_in_direction()`. Beralih ke `Idle` jika input dilepas, atau ke `Roll` jika `dodge` ditekan.
   * **`Roll`**: Mengunci arah gerak ke arah input terakhir atau arah hadap karakter dengan kecepatan `240.0 px/s` selama durasi `0.25 detik`. Mengabaikan input normal selama roll, lalu kembali ke `Move` atau `Idle` secara mulus tergantung input aktif saat roll berakhir.

---

## 6. Modular Visuals System

* Node `ModularVisuals` menampung 10 `Sprite2D` dengan urutan Z-order terstandarisasi.
* **API Pengontrol:**
  * `set_layer_visible(layer_name: StringName, is_visible: bool)`: Menampilkan/menyembunyikan layer pakaian secara dinamis.
  * `set_layer_texture(layer_name: StringName, texture: Texture2D)`: Mengganti tekstur/spritesheet layer saat pemain mengganti equipment.
  * `play_animation(action: StringName, direction: StringName)`: Memutar animasi serempak pada seluruh layer.
  * `set_facing_direction(dir)` / `get_facing_direction()`: Melacak orientasi hadap karakter.

---

## 7. Animation System & Diagonal Mapping

* **Daftar Animasi Aktif (12 Animasi):**
  * `idle_down`, `idle_up`, `idle_left`, `idle_right`
  * `walk_down`, `walk_up`, `walk_left`, `walk_right`
  * `roll_down`, `roll_up`, `roll_left`, `roll_right`
* **Pemetaan Diagonal:**
  * Sumbu dominan input diagonal dipetakan secara matematis ke 4 arah utama (`abs(x) > abs(y)` -> Kiri/Kanan, sebaliknya Atas/Bawah).
  * Menjamin konsistensi pencahayaan sprite tanpa membutuhkan pembuatan sudut diagonal prematur.

---

## 8. Camera System

* Node `Camera2D` terpasang langsung pada `Player`.
* `position_smoothing_enabled = true` dengan kecepatan smoothing `8.0`.
* Bekerja selaras dengan konfigurasi global `snap_2d_transforms_to_pixel` sehingga gerakan kamera tidak memicu distorsi atau getaran sub-piksel (*pixel jitter*).

---

## 9. Touch Controls System

* `TouchVirtualJoystick`: Menangani event `InputEventScreenTouch` dan `InputEventScreenDrag` (serta fallback mouse).
* Dilengkapi dengan `deadzone = 0.1` dan pembatasan radius maksimal (`max_radius = 40.0 px`).
* Tombol sentuh **DODGE** memicu aksi `dodge`.
* Otomatis tersembunyi pada sistem non-touchscreen (`DisplayServer.is_touchscreen_available() == false`) dan dapat dipaksa tampil via flag `force_visible`.

---

## 10. Testing & Validation Results

Pengujian dieksekusi secara otomatis menggunakan Godot 4.7.2 Headless:

### A. Phase 2 Test Suite (`tests/test_phase_2.gd`)
* **Player Scene Structure:** 10/10 assertions PASS.
* **Player Movement & Physics:** 9/9 assertions PASS.
* **Player State Machine:** 6/6 assertions PASS.
* **Modular Visuals System:** 38/38 assertions PASS.
* **Camera System:** 3/3 assertions PASS.
* **Touch Controls System:** 5/5 assertions PASS.
* **Total Phase 2 Assertions:** **73 Passed, 0 Failed.**

### B. Phase 1 Regression Test Suite (`tests/test_phase_1.gd`)
* **Total Phase 1 Assertions:** **45 Passed, 0 Failed.**

### C. Main Scene Execution
* `godot --headless --quit-after 60` berjalan 60 frame tanpa runtime error maupun debugger warning (Exit Code: 0).

---

## 11. Pengujian Manual yang Belum Dilakukan

Sesuai aturan pelaporan yang jujur:
* Pengujian sentuhan fisik pada layar smartphone Android nyata belum dilakukan (menunggu tahap build APK rilis).
* Pengujian multi-touch gesture simultan di browser mobile belum dilakukan.
* Keduanya tercatat sebagai item uji verifikasi manual saat export template telah terpasang.

---

## 12. Known Issues & Technical Debt

* Tidak ada blocker fungsional.
* Penamaan class `VirtualJoystick` sempat bentrok dengan native class engine Godot 4.7, sehingga telah disesuaikan menjadi `TouchVirtualJoystick` secara bersih.

---

## 13. Rekomendasi Phase 3 (World & Exploration)

Dengan karakter yang telah dapat bergerak, berputar 8-arah, melakukan roll, dan memiliki rig visual modular, proyek siap melangkah ke **Phase 3**:
1. Pembangunan arsitektur level menggunakan `TileMapLayer` bertingkat (Ground, Wall, Solid, Overhead).
2. Pengelompokan Y-Sort untuk sorting kedalaman pemain terhadap pohon dan bangunan kampus Untidar.
3. Pembuatan `InteractionComponent` dan `InteractableArea2D` (pintu ruangan, peti, papan pengumuman).
4. Pembuatan `SceneTransitionTrigger` yang terintegrasi dengan `SceneManager`.
