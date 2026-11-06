# Implementation Report: Phase 3 — World & Exploration

- **Tanggal Pelaksanaan:** 2026-11-06
- **Status:** COMPLETED
- **Pelaksana:** Senior Godot Engineer, 2D Level Designer, Gameplay Programmer & Technical Lead
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Renderer:** GL Compatibility
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan seluruh fondasi dunia dan eksplorasi pada **Phase 3: World & Exploration** untuk game *Petualang Untidar*. Lingkup pekerjaan meliputi:
1. Pembangunan arsitektur level 2D top-down berbasis `TileMapLayer` bertingkat sesuai standar Godot 4.3+/4.7.
2. Pengelompokan dan penataan kedalaman visual (Y-Sort) untuk karakter pemain, rintangan solid, dan objek prop.
3. Penetapan matriks tabrakan (*collision matrix*) untuk Layer 1 (World) dan Layer 8 (Interactables).
4. Pembuatan komponen interaksi rekayasa bersih: `InteractionComponent` dan kontrak `Interactable`.
5. Pembangunan tiga objek interaktif fungsional: Peti Harta (`TreasureChest`), Papan Pengumuman Kampus (`InformationBoard`), dan Pintu Antar-Ruangan (`Door`).
6. Perluasan `SceneManager` dengan dukungan transisi scene berdasar ID Spawn Point (`change_scene_with_spawn`).
7. Pembuatan level prototipe Kampus Untidar: Area Halaman Luar (`outdoor_test.tscn`) dan Interior Gedung Kuliah Bersama (`building_test.tscn`).
8. Integrasi kontrol sentuh (tombol `InteractButton` pada `TouchControls`) dan UI kontekstual `PromptLabel`.
9. Integrasi penuh ke `scenes/main/main.tscn` sehingga eksekusi F5 langsung membuka dunia kampus interaktif.
10. Validasi komprehensif menggunakan automated test suite (`tests/test_phase_3.gd`) dengan 100% tingkat kelulusan regresi untuk Phase 1 dan Phase 2.

---

## 2. Objective

1. Mengonfigurasi arsitektur level modular `TileMapLayer` yang memisahkan tanah, dekorasi dinding, entitas dinamis, dan atap/kanopi atas.
2. Menerapkan Y-Sort matematis presisi tanpa *frame tearing* atau anomali kedalaman saat karakter bergerak di depan atau di belakang objek.
3. Memastikan batas dunia (*world boundaries*) memagari pergerakan pemain secara kokoh tanpa glitch penembusan dinding.
4. Menerapkan sistem interaksi terpisah pada Collision Layer 8 (Value 128) yang memprioritaskan objek terdekat via kalkulasi jarak kuadrat Euclidean.
5. Membangun objek peti satu kali buka, papan pengumuman yang memunculkan lore kampus, dan pintu yang memicu transisi scene dengan fade visual.
6. Mengimplementasikan perpindahan antar-area dengan penempatan posisi karakter ke node `Marker2D` yang sesuai.
7. Menyediakan tombol interaksi pada HUD layar sentuh dan petunjuk tombol keyboard `[E]`.
8. Memvalidasi seluruh implementasi melalui 69 assertion automated test di Phase 3 dan memastikan 187 assertion test total proyek lulus tanpa galat.

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
* `scripts/objects/door.gd`: Script pintu doorway antar-ruangan (`class_name Door`).
* `scenes/objects/door.tscn`: Scene pintu dengan target scene, target spawn id, dan `Interactable`.
* `scenes/objects/tree.tscn`: Scene pohon kampus dengan origin Y-sort di pangkal batang dan kanopi rindang.
* `resources/tilesets/world_tileset.tres`: Resource tileset 16x16 dengan Physics Layer 0 (Layer 1 World collision).
* `assets/tilesets/prototype_tileset.png`: Spritesheet tileset lingkungan (rumput, bunga, batu jalan, dinding gedung, lantai dalam).
* `assets/objects/*.png`: 4 tekstur pixel art untuk objek dunia (`chest.png`, `board.png`, `door.png`, `tree.png`).
* `scenes/world/outdoor_test.tscn`: Prototipe area halaman luar Kampus Untidar.
* `scenes/world/building_test.tscn`: Prototipe interior Gedung Kuliah Bersama (GKB).
* `tests/test_phase_3.gd`: Automated test suite untuk Phase 3 (69 assertions).

### B. File yang Dimodifikasi
* `scripts/autoload/scene_manager.gd`: Ditambahkan `target_spawn_point_id: StringName`, method `change_scene_with_spawn()`, dan method `get_and_clear_spawn_point()`.
* `scripts/player/player.gd`: Ditambahkan referensi `@onready var interaction_component` dan method `trigger_interact()`.
* `scenes/player/player.tscn`: Ditambahkan child node `InteractionComponent` (`Area2D`) dengan `CollisionShape2D` radius 24px.
* `scripts/ui/touch/touch_controls.gd`: Ditambahkan tombol `%InteractButton` yang terhubung ke aksi `interact` dan `player.trigger_interact()`.
* `scenes/ui/touch_controls.tscn`: Ditata tata letak tombol sentuh baru untuk interaksi di samping tombol roll.
* `scenes/main/main.tscn`: Diperbarui menjadi instance dari `scenes/world/outdoor_test.tscn` dengan script `scenes/main/main.gd`.
* `scenes/main/main.gd`: Diperbarui menjadi `class_name MainScene extends WorldBase` sebagai entry level proyek.
* `docs/development/roadmap.md`: Status Phase 3 diperbarui menjadi `COMPLETED`.
* `docs/architecture/technical-architecture.md`: Dokumentasi arsitektur level dan interaksi diperbarui.
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
└── HUD (CanvasLayer layer 5 - State, Speed, Facing, Pause Indicator, PromptLabel)
```

---

## 5. Y-Sort & Depth Sorting Hierarchy

* **Pivot dan Anchor Standard:**
  * Semua entitas berkarakter dan objek prop menggunakan anchor titik alas/kaki pada `(0, 0)`.
  * `Player`: Titik origin di `(0, 0)`, kapsul tabrakan kaki di `(0, 8)`.
  * `Tree`: Titik origin di `(0, 0)` (dasar batang), batang pohon di `(0, -6)`, kanopi memanjang ke atas hingga `Y = -54`.
* **Kalkulasi Kedalaman:**
  * Saat `Player.global_position.y < Tree.global_position.y` (pemain berjalan di utara pohon), Godot merender Player di belakang pohon.
  * Saat `Player.global_position.y > Tree.global_position.y` (pemain berjalan di selatan pohon), Godot merender Player di depan pohon menutupi pangkal batang.
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
  * Memancarkan sinyal `availability_changed(available)` jika ketersediaan interaksi berubah (misal peti dibuka).
* **`InteractionComponent` (`Area2D`):**
  * Terpasang pada `Player` dengan `collision_layer = 0` dan `collision_mask = 128`.
  * Menyimpan daftar `_candidates: Array[Interactable]` yang berada dalam jangkauan (radius 24px).
  * Menghitung kandidat terdekat menggunakan `distance_squared_to()` (tanpa akar kuadrat) untuk menghemat kinerja komputasi.
  * Memancarkan sinyal `target_changed(new_target)` yang langsung didengarkan oleh HUD level untuk menampilkan atau menyembunyikan `PromptLabel`.
  * Mendengarkan sinyal `availability_changed` dari kandidat aktif sehingga bila peti terbuka, target otomatis berpindah ke kandidat berikutnya seketika.

---

## 8. Interactive Objects Implementation

1. **Peti Harta (`TreasureChest`):**
   * Visual dua frame: Frame 0 (tertutup) dan Frame 1 (terbuka).
   * Interaksi pertama memanggil `open_chest(actor)`, mengubah frame ke 1, menonaktifkan `is_interactable = false`, memunculkan teks apung `EventBus.show_floating_text`, dan memancarkan sinyal `opened(actor)`.
   * Interaksi lanjutan diabaikan dengan aman.
2. **Papan Informasi Kampus (`InformationBoard`):**
   * Menyimpan `board_title` dan `board_content` yang berisi lore Kampus Untidar (Gedung Kuliah Bersama / GKB).
   * Menampilkan judul informasi di atas papan saat dibaca dan memancarkan sinyal `read(actor)`.
3. **Pintu Ruangan (`Door`):**
   * Properti ekspor: `target_scene_path: String`, `target_spawn_id: StringName`, dan `door_label: String`.
   * Saat diinteraksi, memanggil `SceneManager.change_scene_with_spawn(target_scene_path, target_spawn_id, true)`.
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
  * Prompt langsung disembunyikan saat pemain menjauh atau objek selesai digunakan.
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

## 13. Automated Test Suite Results (`test_phase_3.gd`)

Validasi otomatis dieksekusi menggunakan perintah:
`godot --headless -s tests/test_phase_3.gd`

```text
=======================================================
>>> STARTING PHASE 3 AUTOMATED VALIDATION SUITE <<<
=======================================================

--- 1. Testing World Scenes Structure ---
  [PASS] outdoor_test.tscn loaded successfully
  [PASS] outdoor_test.tscn root is WorldBase class
  [PASS] outdoor_test contains GroundLayer (TileMapLayer)
  [PASS] outdoor_test contains WallDecorationLayer (TileMapLayer)
  [PASS] outdoor_test contains YSortEntities (Node2D)
  [PASS] outdoor_test contains OverheadLayer (TileMapLayer)
  [PASS] outdoor_test contains WorldBoundaries (StaticBody2D)
  [PASS] outdoor_test contains SpawnPoints (Node2D)
  [PASS] outdoor_test contains Player in YSortEntities
  [PASS] outdoor_test contains TouchControls
  [PASS] outdoor_test contains HUD (CanvasLayer)
  [PASS] building_test.tscn loaded successfully
  [PASS] building_test.tscn root is WorldBase class
  [PASS] building_test contains GroundLayer (TileMapLayer)
  [PASS] building_test contains YSortEntities (Node2D)
  [PASS] building_test contains WorldBoundaries (StaticBody2D)
  [PASS] building_test contains SpawnPoints (Node2D)
  [PASS] building_test contains Player in YSortEntities
  [PASS] main.tscn loaded successfully
  [PASS] main.tscn root inherits WorldBase
  [PASS] main.tscn root is MainScene class

--- 2. Testing Y-Sort & Layering Hierarchy ---
  [PASS] YSortEntities has y_sort_enabled = true
  [PASS] OverheadLayer has z_index >= 5 to render above characters
  [PASS] YSortEntities/Interactables has y_sort_enabled = true
  [PASS] Tree prop has y_sort_enabled = true
  [PASS] Entity with lower Y renders behind object base in Y-Sort
  [PASS] Entity with higher Y renders in front of object base in Y-Sort

--- 3. Testing Collision Layers & Boundaries ---
  [PASS] WorldBoundaries exists
  [PASS] WorldBoundaries collision_layer includes Layer 1 (World)
  [PASS] WorldBoundaries has boundary collision shapes for map borders
  [PASS] Player exists in level
  [PASS] Player collision_mask includes Layer 1 (World obstacles)
  [PASS] Tree1 exists
  [PASS] Tree collision_layer includes Layer 1 (Solid World)

--- 4. Testing InteractionComponent & Interactable ---
  [PASS] InteractionComponent scans Layer 8 (bit 7: 128)
  [PASS] InteractionComponent collision_layer is 0
  [PASS] Interactable is on Layer 8 (bit 7: 128)
  [PASS] Interactable is in 'interactable' group
  [PASS] Far object detected as initial target
  [PASS] Near object takes priority as closest target
  [PASS] trigger_interact() triggers target's interacted signal
  [PASS] Disabling closest target falls back to next candidate
  [PASS] Exiting area clears current target to null

--- 5. Testing Interactive Objects ---
  [PASS] treasure_chest.tscn loaded successfully
  [PASS] TreasureChest initial is_opened = false
  [PASS] TreasureChest initial is_interactable = true
  [PASS] TreasureChest sprite frame is 0 (closed)
  [PASS] TreasureChest is_opened is true after opening
  [PASS] TreasureChest disables interaction after opening
  [PASS] TreasureChest sprite frame updated to 1 (opened)
  [PASS] TreasureChest emitted opened signal
  [PASS] information_board.tscn loaded successfully
  [PASS] InformationBoard has board_title
  [PASS] InformationBoard has board_content
  [PASS] InformationBoard interaction emits read signal
  [PASS] door.tscn loaded successfully
  [PASS] Door contains Interactable component
  [PASS] Door default target_spawn_id is &"default"

--- 6. Testing Scene Transitions & Spawn Points ---
  [PASS] SceneManager autoload is present
  [PASS] SceneManager sets target_spawn_point_id
  [PASS] get_and_clear_spawn_point() returns correct ID
  [PASS] get_and_clear_spawn_point() clears spawn ID to empty
  [PASS] SpawnPoints contains 'from_building' marker
  [PASS] Player correctly positioned at 'from_building' marker

--- 7. Testing Touch Controls & HUD Prompt ---
  [PASS] WorldBase has TouchControls reference
  [PASS] TouchControls contains interact_button (%InteractButton)
  [PASS] PromptLabel is visible when interactable in range
  [PASS] PromptLabel displays interaction text
  [PASS] PromptLabel is hidden when target is null

=======================================================
>>> PHASE 3 VALIDATION SUMMARY <<<
Passed: 69
Failed: 0
=======================================================
[SUCCESS] All Phase 3 world & exploration components validated with 0 errors!
```

---

## 14. Regression Testing Results (Phase 1, Phase 2, Phase 3)

Seluruh suite pengujian otomatis dijalankan berturut-turut untuk memastikan stabilitas ekosistem:

| Suite Pengujian | Target Modul | Jumlah Assertion | Status |
| :--- | :--- | :---: | :---: |
| `tests/test_phase_1.gd` | Core Settings, Inputs, Autoloads, Components, FSM | 45 | **PASS (45/45)** |
| `tests/test_phase_2.gd` | Player Entity, 8-Dir Move, ModularVisuals, Camera, Touch | 73 | **PASS (73/73)** |
| `tests/test_phase_3.gd` | TileMapLayer, Y-Sort, Boundaries, Interaction, Doors, Spawns | 69 | **PASS (69/69)** |
| **TOTAL** | **Seluruh Fondasi Proyek Petualang Untidar** | **187** | **100% PASS** |

Pengujian eksekusi simulasi 60 frame `scenes/main/main.tscn` berhasil keluar dengan kode exit `0` tanpa *memory leak* tak tertangani.

---

## 15. Platform Compatibility Evaluation (Web & Android)

1. **Web (HTML5 / WebAssembly):**
   * Penggunaan `TileMapLayer` dan atlas tekstur tunggal `resources/tilesets/world_tileset.tres` meminimalkan draw call pada WebGL 2.0 (GL Compatibility).
   * Tekstur Nearest Filtering mencegah blur pada kanvas browser.
2. **Android (GLES3 / Touchscreen):**
   * Orientasi `sensor_landscape` tetap terjaga.
   * Tombol `InteractButton` pada `TouchControls` berukuran $52 \times 52$ piksel dengan margin yang nyaman bagi jempol kanan pengguna mobile, tanpa menghalangi tombol Roll atau joystick kiri.

---

## 16. Architectural Decisions & Next Phase Readiness (Phase 4 Combat)

Fondasi yang dibangun pada Phase 3 telah siap secara arsitektural untuk menyambut **Phase 4: Combat System**:
* Matriks collision telah menyediakan slot bersih untuk combat: Layer 3 (Player Hurtbox), Layer 4 (Player Hitbox), Layer 5 (Enemy Body), Layer 6 (Enemy Hurtbox), dan Layer 7 (Enemy Hitbox) tanpa bentrok dengan Layer 1 (World) atau Layer 8 (Interactables).
* Entitas musuh (`BaseEnemy.tscn`) nantinya dapat langsung dimasukkan ke dalam container `YSortEntities` sehingga tersortir kedalamannya secara otomatis bersama Player dan pohon.
* Sinyal `EventBus.show_floating_text` yang telah teruji pada Phase 3 dapat langsung dimanfaatkan untuk memunculkan angka damage pertempuran (*floating combat text*).

**Kesimpulan:** Implementasi Phase 3 telah selesai sepenuhnya dengan status **COMPLETED** dan siap untuk direview. Pekerjaan Phase 4 tidak akan dimulai sebelum ada persetujuan resmi.
