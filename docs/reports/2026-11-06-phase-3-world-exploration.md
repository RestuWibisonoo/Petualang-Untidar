# Implementation Report: Phase 3 — World & Exploration (Reviewed & Fixed)

- **Tanggal Pelaksanaan:** 2026-11-06
- **Status:** COMPLETED & REVIEW VERIFIED
- **Pelaksana:** Senior Godot Engineer, 2D Level Designer, Gameplay Programmer & Technical Lead
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Renderer:** GL Compatibility
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan seluruh fondasi dunia dan eksplorasi pada **Phase 3: World & Exploration** untuk game *Petualang Untidar* serta menuntaskan seluruh poin audit review:
1. Pembangunan arsitektur level 2D top-down berbasis `TileMapLayer` bertingkat sesuai standar Godot 4.3+/4.7.
2. Pengelompokan dan penataan kedalaman visual (Y-Sort) untuk karakter pemain, rintangan solid, dan objek prop.
3. Penetapan matriks tabrakan (*collision matrix*) untuk Layer 1 (World) dan Layer 8 (Interactables).
4. Pembuatan komponen interaksi rekayasa bersih: `InteractionComponent` dan kontrak `Interactable`.
5. Pembangunan tiga objek interaktif fungsional: Peti Harta (`TreasureChest`), Papan Pengumuman Kampus (`InformationBoard`), dan Pintu Antar-Ruangan (`Door`).
6. **Perbaikan Information Board:** Membangun UI panel utuh (`InfoDialogPanel`) yang menampilkan judul dan isi teks lengkap, mendukung navigasi keyboard (ESC/E/Enter) serta sentuh (Close Button/Backdrop), dengan pencegahan interaksi berulang dan pembekuan karakter saat membaca.
7. Perluasan `SceneManager` dengan dukungan transisi scene berdasar ID Spawn Point (`change_scene_with_spawn`) dan proteksi terhadap panggilan transisi ganda.
8. Pembuatan level prototipe Kampus Untidar: Area Halaman Luar (`outdoor_test.tscn`) dan Interior Gedung Kuliah Bersama (`building_test.tscn`).
9. Integrasi kontrol sentuh (tombol `InteractButton` pada `TouchControls`) dan UI kontekstual `PromptLabel`.
10. Integrasi penuh ke `scenes/main/main.tscn` sehingga eksekusi F5 langsung membuka dunia kampus interaktif.
11. Pengujian terpisah: Automated unit tests (89 assertions), Runtime physics & loop tests (33 assertions), Manual visual test, dan status pengujian fisik Android.

---

## 2. Objective

1. Mengonfigurasi arsitektur level modular `TileMapLayer` yang memisahkan tanah, dekorasi dinding, entitas dinamis, dan atap/kanopi atas.
2. Menerapkan Y-Sort matematis presisi tanpa *frame tearing* atau anomali kedalaman saat karakter bergerak di depan atau di belakang objek.
3. Memastikan batas dunia (*world boundaries*) memagari pergerakan pemain secara kokoh tanpa glitch penembusan dinding.
4. Menerapkan sistem interaksi terpisah pada Collision Layer 8 (Value 128) yang memprioritaskan objek terdekat via kalkulasi jarak kuadrat Euclidean.
5. Membangun objek peti satu kali buka, panel pengumuman yang memunculkan teks lore kampus secara lengkap, dan pintu yang memicu transisi scene dengan fade visual.
6. Mengimplementasikan perpindahan antar-area dengan penempatan posisi karakter ke node `Marker2D` yang sesuai.
7. Menyediakan tombol interaksi pada HUD layar sentuh dan petunjuk tombol keyboard `[E]`.
8. Memvalidasi seluruh implementasi melalui 89 assertion automated test dan 33 assertion runtime test di Phase 3 (total proyek 240 assertions lulus tanpa galat).

---

## 3. Files Created & Modified

### A. File Baru Dibuat
* `scripts/world/world_base.gd`: Base controller untuk semua level dan area eksplorasi (`class_name WorldBase`).
* `scripts/components/interactable.gd`: Komponen dasar area interaksi pada objek (`class_name Interactable`).
* `scripts/components/interaction_component.gd`: Komponen pemindai dan eksekutor interaksi pada Player (`class_name InteractionComponent`).
* `scripts/objects/treasure_chest.gd`: Script controller peti harta interaktif (`class_name TreasureChest`).
* `scenes/objects/treasure_chest.tscn`: Scene peti harta dengan sprite buka/tutup dan komponen `Interactable`.
* `scripts/objects/information_board.gd`: Script controller papan pengumuman kampus (`class_name InformationBoard`).
* `scenes/objects/information_board.tscn`: Scene papan pengumuman dengan teks lore Untidar dan `Interactable`.
* `scripts/ui/info_dialog_panel.gd`: Script controller panel modal baca informasi (`class_name InfoDialogPanel`).
* `scenes/ui/info_dialog_panel.tscn`: Scene panel modal baca informasi kampus dengan backdrop dan tombol tutup.
* `scripts/objects/door.gd`: Script pintu doorway antar-ruangan (`class_name Door`).
* `scenes/objects/door.tscn`: Scene pintu dengan target scene, target spawn id, dan `Interactable`.
* `scenes/objects/tree.tscn`: Scene pohon kampus dengan origin Y-sort di pangkal batang dan kanopi rindang.
* `resources/tilesets/world_tileset.tres`: Resource tileset 16x16 dengan Physics Layer 0 (Layer 1 World collision).
* `assets/tilesets/prototype_tileset.png`: Spritesheet tileset lingkungan (rumput, bunga, batu jalan, dinding gedung, lantai dalam).
* `assets/objects/*.png`: 4 tekstur pixel art untuk objek dunia (`chest.png`, `board.png`, `door.png`, `tree.png`).
* `scenes/world/outdoor_test.tscn`: Prototipe area halaman luar Kampus Untidar.
* `scenes/world/building_test.tscn`: Prototipe interior Gedung Kuliah Bersama (GKB).
* `tests/test_phase_3.gd`: Automated test suite untuk Phase 3 (89 assertions).
* `tests/runtime_validation_phase_3.gd`: Runtime simulation test suite untuk fisika, Y-Sort, transisi scene, dan UI (33 assertions).

### B. File yang Dimodifikasi
* `scripts/autoload/event_bus.gd`: Ditambahkan sinyal `info_panel_requested(title, content)` dan `info_panel_closed`.
* `scripts/autoload/scene_manager.gd`: Ditambahkan `target_spawn_point_id: StringName`, method `change_scene_with_spawn()`, dan method `get_and_clear_spawn_point()`.
* `scripts/player/player.gd`: Ditambahkan referensi `@onready var interaction_component` dan method `trigger_interact()`.
* `scenes/player/player.tscn`: Ditambahkan child node `InteractionComponent` (`Area2D`) dengan `CollisionShape2D` radius 24px.
* `scripts/ui/touch/touch_controls.gd`: Ditambahkan tombol `%InteractButton` yang terhubung ke aksi `interact` dan `player.trigger_interact()`.
* `scenes/ui/touch_controls.tscn`: Ditata tata letak tombol sentuh baru untuk interaksi di samping tombol roll.
* `scenes/main/main.tscn`: Diperbarui menjadi instance dari `scenes/world/outdoor_test.tscn` dengan script `scenes/main/main.gd`.
* `scenes/main/main.gd`: Diperbarui menjadi `class_name MainScene extends WorldBase` sebagai entry level proyek.
* `docs/development/roadmap.md`: Status Phase 3 diperbarui menjadi `COMPLETED`.
* `docs/architecture/technical-architecture.md`: Dokumentasi arsitektur level, interaksi, dan UI panel diperbarui.
* `docs/decisions/technical-decisions.md`: Ditambahkan ADR-013, ADR-014, dan ADR-015.

---

## 4. World & Exploration Architecture

Arsitektur level mengadopsi standar Godot 4.3+/4.7 dengan node `TileMapLayer` mandiri yang menggantikan node `TileMap` usang:

```text
WorldBase (Node2D) [Script: world_base.gd]
├── GroundLayer (TileMapLayer - Z-index: 0, tanpa tabrakan)
├── WallDecorationLayer (TileMapLayer - Z-index: 0, dekorasi lantai & dinding bawah)
├── YSortEntities (Node2D - y_sort_enabled = true)
│   ├── SolidObjectsLayer (TileMapLayer - y_sort_enabled = true, collision layer 1)
│   ├── Player (CharacterBody2D - y_sort_enabled = true, origin di kaki)
│   └── Interactables (Node2D - y_sort_enabled = true)
│       ├── TreasureChest (StaticBody2D)
│       ├── InformationBoard (StaticBody2D)
│       ├── CampusDoor / ExitDoor (Node2D)
│       └── Tree1, Tree2, Tree3 (StaticBody2D)
├── OverheadLayer (TileMapLayer - Z-index: 5, atap gedung & kanopi pohon)
├── WorldBoundaries (StaticBody2D - Collision Layer 1, penahan pemain di batas map)
│   ├── TopBoundary (CollisionShape2D)
│   ├── BottomBoundary (CollisionShape2D)
│   ├── LeftBoundary (CollisionShape2D)
│   └── RightBoundary (CollisionShape2D)
├── SpawnPoints (Node2D - Penampung titik awal/muncul pemain)
│   ├── default (Marker2D)
│   └── from_building / from_outdoor (Marker2D)
├── TouchControls (CanvasLayer layer 10 - Joystick virtual & Action/Interact Buttons)
└── HUD (CanvasLayer layer 5)
    ├── MarginContainer (Diagnostik State, Speed, Facing, Pause)
    ├── PromptLabel (Teks prompt [E] interaksi kontekstual)
    ├── ZoneLabel (Label nama zona/area)
    └── InfoDialogPanel (Control - Modal pembaca informasi & lore kampus)
```

---

## 5. Y-Sort & Depth Sorting Hierarchy

* **Pivot dan Anchor Standard:**
  * Semua entitas berkarakter dan objek prop menggunakan anchor titik alas/kaki pada `(0, 0)`.
  * `Player`: Titik origin di `(0, 0)`, kapsul tabrakan kaki di `(0, 8)`.
  * `Tree`: Titik origin di `(0, 0)` (dasar batang), batang pohon di `(0, -2)` (radius 8), kanopi memanjang ke atas hingga `Y = -60`.
* **Kalkulasi Kedalaman Aktual:**
  * Saat `Player.global_position.y > Tree.global_position.y` (pemain berjalan di selatan pohon, misal $Y = 50$), Godot merender Player di depan pohon menutupi batang.
  * Saat `Player.global_position.y < Tree.global_position.y` (pemain berjalan di utara pohon, misal $Y = -10$), Godot merender Player di belakang kanopi pohon.
* **Overhead Protection:**
  * `OverheadLayer` diberi nilai `z_index = 5` dan diletakkan di luar `YSortEntities`, menjamin bahwa atap atau dedaunan tinggi selalu menaungi pemain di bawahnya tanpa memandang koordinat Y pemain.

---

## 6. Collision Matrix & Environmental Boundaries

Sistem tabrakan Phase 3 mematuhi matriks layer proyek:

| Layer | Nama Layer | Nilai Bitmask | Fungsi pada Phase 3 |
| :---: | :--- | :---: | :--- |
| **Layer 1** | World | `1` (Bit 0) | Dinding solid, rintangan `TileMapLayer`, batas tepi `WorldBoundaries`, dan batang pohon padat. |
| **Layer 2** | Player Body | `2` (Bit 1) | Kapsul tabrakan kaki pemain (Mask = `1`, bertabrakan dengan World). |
| **Layer 8** | Interactables | `128` (Bit 7) | Area deteksi objek interaktif (Mask = `0`, hanya dipindai oleh Player). |

`WorldBoundaries` ditempatkan mengelilingi area bermain (640x500 pada outdoor) untuk mencegah karakter keluar dari batas pandang kamera.

---

## 7. Component-Based Interaction System

Sistem interaksi dirancang tanpa ketergantungan erat (*decoupled*):
* **`Interactable` (`Area2D`):**
  * Ditempatkan pada objek dunia dengan `collision_layer = 128` dan `collision_mask = 0`.
  * Menyediakan properti `interaction_text`, status `is_interactable`, dan sinyal `interacted(actor)`.
  * Memancarkan sinyal `availability_changed(available)` jika ketersediaan interaksi berubah (misal peti dibuka atau papan sedang dibaca).
* **`InteractionComponent` (`Area2D`):**
  * Terpasang pada `Player` dengan `collision_layer = 0` dan `collision_mask = 128`.
  * Menyimpan daftar `_candidates: Array[Interactable]` yang berada dalam jangkauan (radius 24px).
  * Menghitung kandidat terdekat menggunakan `distance_squared_to()` (tanpa kalkulasi akar kuadrat yang membebani CPU).
  * Memancarkan sinyal `target_changed(new_target)` yang langsung didengarkan oleh HUD level untuk menampilkan atau menyembunyikan `PromptLabel`.
  * Mendengarkan sinyal `availability_changed` dari kandidat aktif sehingga bila sebuah objek dinonaktifkan, target otomatis berpindah atau dibersihkan seketika.

---

## 8. Interactive Objects & Information Board Implementation

1. **Peti Harta (`TreasureChest`):**
   * Visual dua frame: Frame 0 (tertutup) dan Frame 1 (terbuka).
   * Interaksi pertama memanggil `open_chest(actor)`, mengubah frame ke 1, menonaktifkan `is_interactable = false`, memunculkan teks apung `EventBus.show_floating_text`, dan memancarkan sinyal `opened(actor)`.
   * Interaksi lanjutan diabaikan dengan aman.
2. **Papan Informasi Kampus (`InformationBoard`) & `InfoDialogPanel`:**
   * Menyimpan `board_title` dan `board_content` yang berisi informasi lengkap kampus Untidar.
   * Saat dibaca, memancarkan sinyal `read(actor)` dan meminta pembukaan panel melalui `EventBus.info_panel_requested(title, content)`.
   * **Pencegahan Spam:** Seketika saat dibuka, `is_reading = true` dan `interactable.is_interactable = false`, sehingga pemain tidak dapat memicu interaksi berulang.
   * **Pembekuan Pemain:** `WorldBase` membekukan fisika pemain (`player.set_physics_process(false)`) dan menghentikan sisa kecepatan agar karakter tidak meluncur saat membaca.
   * **Tampilan Modal:** `InfoDialogPanel` di HUD terbuka dengan backdrop semi-transparan, judul emas, dan teks konten multiline ter-autowrap.
   * **Dukungan Ganda:**
     * Keyboard: Dapat ditutup menggunakan tombol Escape, E, atau Enter.
     * Layar Sentuh: Dilengkapi tombol `TUTUP [X]` berukuran sentuh nyaman serta pengetukan pada backdrop luar.
   * **Pemulihan Bersih:** Saat ditutup, `EventBus.info_panel_closed` dipancarkan, `InfoDialogPanel` disembunyikan, pergerakan pemain diaktifkan kembali, dan ketersediaan interaksi papan dipulihkan.
   * **Pencegahan Duplikasi:** Menggunakan 1 instance panel reusable di HUD, tanpa menginstansiasi node baru di setiap interaksi.
3. **Pintu Ruangan (`Door`):**
   * Properti ekspor: `target_scene_path: String`, `target_spawn_id: StringName`, dan `door_label: String`.
   * Pengecekan `SceneManager.is_transitioning()` mencegah pemanggilan transisi ganda saat fade masih berlangsung.
   * Memanggil `SceneManager.change_scene_with_spawn(target_scene_path, target_spawn_id, true)`.
   * Jika path kosong atau tidak valid, menampilkan teks melayang *"Pintu terkunci."* tanpa menyebabkan crash engine.

---

## 9. Scene Transitions & Spawn Point Routing

* **SceneManager Extension:**
  * Variabel `target_spawn_point_id: StringName` menyimpan target spawn antar transisi.
  * Layar hitam fade-overlay (CanvasLayer 100) melakukan tween alpha $0 \to 1$ selama 0.3 detik, mengeksekusi pergantian scene, lalu melakukan fade-in $1 \to 0$.
* **WorldBase Spawn Resolution:**
  * Saat `_ready()` level dipanggil, `_handle_spawn_point()` memanggil `SceneManager.get_and_clear_spawn_point()`.
  * Script mencari node `Marker2D` di dalam kontainer `SpawnPoints` yang namanya cocok dengan spawn ID.
  * Pemain langsung dipindahkan ke koordinat global marker tersebut (`player.global_position = spawn_node.global_position`).
  * Jika ID kosong atau tidak ditemukan, level otomatis menggunakan marker default.

---

## 10. UI Prompt & Mobile Touch Interaction Integration

* **Kontekstual Prompt (`PromptLabel`):**
  * Teks `[E] <Teks Aksi>` muncul di tengah-bawah layar saat pemain mendekati objek dalam radius 24px.
  * Prompt langsung disembunyikan saat pemain menjauh, objek dinonaktifkan, atau saat panel informasi sedang terbuka.
* **Touch Button (`InteractButton`):**
  * Node `%InteractButton` terintegrasi pada `TouchControls` di samping tombol Roll.
  * Menekan tombol sentuh langsung memicu aksi input `"interact"` dan memanggil `player.trigger_interact()`.

---

## 11. Test Environment — Kampus Untidar Prototype

Dua scene saling terhubung berhasil dibangun:
1. **`scenes/world/outdoor_test.tscn` (Halaman Luar Kampus):**
   * Dimensi area $40 \times 30$ tile (luas $640 \times 480$ px).
   * Dilengkapi jalan setapak batu, petak rumput, hamparan bunga kampus, 3 pohon Untidar berkedalaman Y-Sort, peti catatan kuliah, papan informasi fakultas, dan pintu masuk GKB.
   * Spawn points: `default` (titik tengah lapangan) dan `from_building` (tepat di depan pintu masuk).
2. **`scenes/world/building_test.tscn` (Interior GKB):**
   * Dimensi area $20 \times 16$ tile (luas $320 \times 256$ px).
   * Lantai keramik dalam ruangan, dinding batas berkolisi, papan pengumuman tata tertib, dan pintu keluar ke halaman kampus.
   * Spawn points: `default` (tengah ruangan) dan `from_outdoor` (di depan pintu keluar).

---

## 12. Main Scene Integration & Verification

* `scenes/main/main.tscn` dijadikan turunan terwaris (*inherited scene*) dari `scenes/world/outdoor_test.tscn`.
* Script `scenes/main/main.gd` mendefinisikan `class_name MainScene extends WorldBase`.
* Menjalankan proyek melalui F5 (`run/main_scene="res://scenes/main/main.tscn"`) langsung menampilkan dunia luar kampus Untidar dengan kamera mengikuti pergerakan pemain, diagnostik HUD lengkap, dan dukungan kendali ganda (keyboard + touch).

---

## 13. Hasil Pengujian Terstruktur

Pengujian dibagi secara tegas menjadi 4 kategori pengujian:

### 13.1 Automated Component & Unit Tests (`tests/test_phase_3.gd`)
Dijalankan via: `godot --headless -s tests/test_phase_3.gd`
* **Hasil:** **89 assertions PASSED, 0 FAILED**.
* Menguji: Struktur node semua scene level, ketersediaan layer, Y-sort enabled, collision bitmask, interaction queue, open/close InformationBoard, panel display & keyboard/touch close, chest one-time open, door parameter validation, spawn point routing logic, dan touch control hooks.

### 13.2 Runtime Physics & Transition Simulation (`tests/runtime_validation_phase_3.gd`)
Dijalankan via: `godot --headless -s tests/runtime_validation_phase_3.gd`
* **Hasil:** **33 assertions PASSED, 0 FAILED**.
* **Uji Tabrakan Batang Pohon:** Karakter bergerak lurus ke utara menuju pohon di `(-120, 20)`. Berhenti di titik kontak presisi $Y = 24.0$ tanpa penetrasi ke batang ($Y < 23.5$).
* **Uji Tabrakan Dinding TileMapLayer:** Karakter bergerak ke utara menuju dinding solid di `Y = -120`. Berhenti di $Y = -114.0$ tanpa tembus.
* **Uji Batas Map:** Karakter bergerak ke barat menuju pembatas map di `X = -330`. Berhenti di $X = -314.0$.
* **Uji Sliding Sudut Diagonal:** Karakter mendorong sudut kiri-atas `Vector2(-1, -1)`. Karakter tertahan tanpa penetrasi batas ($X \ge -322, Y \ge -242$), dan saat arah diubah ke kanan `Vector2(1, 0)`, karakter meluncur bebas ($X$ naik dari $-314 \to -273.9$) tanpa macet/deadlock.
* **Uji Y-Sort Dinamis:** Karakter di selatan pohon ($Y = 50$) terbukti berposisi di depan pohon; di utara pohon ($Y = -10$) terbukti di belakang kanopi. `OverheadLayer` dengan $Z=5$ selalu di atas karakter.
* **Uji Live Information Board:** Interaksi membuka modal, mengisi judul dan konten, membekukan physics pemain, mematikan interaksi board; penutupan modal memulihkan physics dan mengaktifkan kembali interaksi board.
* **Uji Loop Transisi Nyata:**
  * Outdoor spawn `default`: `(0, 40)`
  * Transisi ke Building spawn `from_outdoor`: `(0, 75)` (bukan default)
  * Transisi kembali ke Outdoor spawn `from_building`: `(0, -85)` (bukan default)
  * Proteksi transisi ganda aktif menolak panggilan beruntun saat transisi sedang berjalan.

### 13.3 Manual Visual & Interactive Tests
* Berjalan di sekitar pohon Untidar: Sorting visual antara dedaunan dan tubuh karakter bertransisi mulus tanpa flickering.
* Membaca papan pengumuman: Panel popup muncul di tengah layar, teks tajam terbaca jelas pada viewport 640x360, tombol `TUTUP [X]` dapat diklik mouse, tombol `ESC` dan `E` menutup panel secara instan.
* Berjalan melewati doorway: Fade hitam menutup layar secara halus, karakter muncul di depan gedung/di dalam ruangan tanpa jeda janggal.

### 13.4 Status Pengujian Perangkat Android Fisik
* **Status Saat Ini:** **BELUM DILAKUKAN PADA HARDWARE HP FISIK**.
* **Pengujian Sentuh yang Telah Divalidasi:** Validasi touchscreen emulation di Godot (`DisplayServer.is_touchscreen_available()`), sensor orientasi landscape, tombol `InteractButton` ($50 \times 50$ px), joystick sentuh analog, dan pengetukan tombol tutup modal.
* **Rencana Pengujian Fisik:** Build APK/AAB dan testing langsung pada smartphone Android dijadwalkan pada **Phase 8: Deployment & Optimization**.

---

## 14. Regression Testing Results (Phase 1, Phase 2, Phase 3)

Seluruh suite pengujian otomatis dijalankan berturut-turut untuk memastikan stabilitas ekosistem:

| Suite Pengujian | Target Modul | Jumlah Assertion | Status |
| :--- | :--- | :---: | :---: |
| `tests/test_phase_1.gd` | Core Settings, Inputs, Autoloads, Components, FSM | 45 | **PASS (45/45)** |
| `tests/test_phase_2.gd` | Player Entity, 8-Dir Move, ModularVisuals, Camera, Touch | 73 | **PASS (73/73)** |
| `tests/test_phase_3.gd` | TileMapLayer, Y-Sort, Boundaries, Interaction, Doors, InfoDialog | 89 | **PASS (89/89)** |
| `tests/runtime_validation_phase_3.gd` | Collision physics, corner sliding, live loop, info panel in level | 33 | **PASS (33/33)** |
| **TOTAL** | **Seluruh Fondasi Proyek Petualang Untidar** | **240** | **100% PASS** |

Pengujian eksekusi simulasi 60 frame `scenes/main/main.tscn` berhasil keluar dengan kode exit `0` tanpa error konsol.

---

## 15. Known Issues & Observasi Teknis

1. **TileMapLayer Physics Flushing di Godot 4:**
   - Objek `TileMapLayer` menginisialisasi quadrant collision bodies secara asinkron pada frame physics pertama. Pengujian headless physics wajib memanggil `await physics_frame` sebelum mengeksekusi kalkulasi tabrakan `move_and_slide()`.
2. **Simulasi Perangkat Mobile:**
   - Walaupun kontrol sentuh telah lulus 100% pada emulasi layar sentuh, pengujian gesture multi-touch kompleks pada hardware Android bertipe layar notch / cut-out tetap perlu ditinjau saat penyusunan pipeline export di Phase 8.

---

## 16. Architectural Decisions & Next Phase Readiness (Phase 4 Combat)

Fondasi yang dibangun pada Phase 3 telah siap secara arsitektural untuk menyambut **Phase 4: Combat System**:
* Matriks collision telah menyediakan slot bersih untuk combat: Layer 3 (Player Hurtbox), Layer 4 (Player Hitbox), Layer 5 (Enemy Body), Layer 6 (Enemy Hurtbox), dan Layer 7 (Enemy Hitbox) tanpa bentrok dengan Layer 1 (World) atau Layer 8 (Interactables).
* Entitas musuh (`BaseEnemy.tscn`) nantinya dapat langsung dimasukkan ke dalam container `YSortEntities` sehingga tersortir kedalamannya secara otomatis bersama Player dan pohon.
* Sinyal `EventBus.show_floating_text` yang telah teruji pada Phase 3 dapat langsung dimanfaatkan untuk memunculkan angka damage pertempuran (*floating combat text*).

**Kesimpulan:** Seluruh perbaikan review Phase 3 telah diselesaikan dengan status **COMPLETED & REVIEW VERIFIED**. Pekerjaan Phase 4 tidak akan dimulai sebelum ada persetujuan resmi berikutnya.
