# Development Roadmap: Petualang Untidar

- **Dokumen:** Peta Jalan Pengembangan Proyek
- **Target Engine:** Godot Engine 4.7.2
- **Arsitektur:** 2D Top-Down Pixel Art Action RPG
- **Status Roadmap:** ACTIVE
- **Terakhir Diperbarui:** 2026-11-06

---

## Ringkasan Status Fase Pengembangan

| Fase | Nama Fase | Status | Estimasi Urutan |
| :---: | :--- | :---: | :---: |
| **Phase 1** | Project Foundation | **COMPLETED** | 1 (Immediate Next) |
| **Phase 2** | Character Foundation | **COMPLETED** | 2 |
| **Phase 3** | World & Exploration | **COMPLETED** | 3 |
| **Phase 4** | Combat System | **COMPLETED** | 4 |
| **Phase 5** | Loot & Progression | **COMPLETED** | 5 |
| **Phase 6** | Quest & Dungeon | **PLANNED** | 6 |
| **Phase 7** | UI & Persistence | **PLANNED** | 7 |
| **Phase 8** | Deployment & Optimization | **PLANNED** | 8 |

---

## Phase 1: Project Foundation

* **Tujuan:** Membangun fondasi engine, konfigurasi pixel-perfect, sistem input cross-platform, struktur direktori terstandarisasi, dan Autoload manajer inti.
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated test suite, 45/45 assertions pass)
* **Dependencies:** Tidak ada.
* **Daftar Pekerjaan:**
  1. Standarisasi `project.godot`:
     - Resolusi dasar `640x360`, mode `viewport`, aspect `keep`.
     - Pixel snapping: `snap_2d_transforms_to_pixel` & `snap_2d_vertices_to_pixel`.
     - Texture filtering: `Nearest` (`default_texture_filter=0`).
     - Konfigurasi Input Action mapping lengkap (8 arah, aksi, interaksi, pause).
  2. Pembuatan struktur direktori proyek lengkap (`assets/`, `scenes/`, `scripts/`, `resources/`, `docs/`, `tests/`).
  3. Pembuatan Autoload inti dengan interface dasar:
     - `EventBus.gd`
     - `GameManager.gd`
     - `AudioManager.gd`
     - `SceneManager.gd`
  4. Pembuatan base framework:
     - `State.gd` dan `StateMachine.gd`
     - `HealthComponent.gd`
     - `VelocityComponent.gd`
     - `HitboxComponent.gd` dan `HurtboxComponent.gd`
* **Expected Deliverables:**
  - File `project.godot` yang telah dikonfigurasi pixel-perfect.
  - Struktur folder bersih di `scenes/`, `scripts/`, `resources/`, dan `assets/`.
  - Autoload terdaftar dan aktif di scene tree.
  - Komponen inti siap pakai.
* **Acceptance Criteria:**
  - Game dapat dijalankan (`F5`) tanpa error script atau missing reference.
  - Input event mendeteksi tombol keyboard, game controller, dan event sentuh.
  - Tekstur pixel art yang diimpor tidak mengalami blur atau distorsi pixel saat window di-resize.

---

## Phase 2: Character Foundation

* **Tujuan:** Mengimplementasikan pergerakan 8 arah pemain yang responsif, visual controller modular (tubuh, rambut, pakaian, senjata), serta kontrol sentuh (Virtual Joystick).
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated test suite, 73/73 assertions pass)
* **Dependencies:** Phase 1 (Project Foundation & Core Components).
* **Daftar Pekerjaan:**
  1. Implementasi entity `player.tscn` dan `player.gd` berbasis `CharacterBody2D`.
  2. Implementasi FSM Player: `PlayerIdleState`, `PlayerMoveState`, `PlayerRollState`.
  3. Pembangunan `ModularVisuals` (10 layer sprite tersinkronisasi) dengan 1 master `AnimationPlayer`.
  4. Logika mapping vektor input 8 arah ke nama animasi (`down`, `down_right`, `right`, dll.).
  5. Pembuatan komponen `VirtualJoystick.tscn` (dynamic floating touch joystick) untuk Web & Android.
  6. Integrasi `Camera2D` dengan batas viewport dan smoothing.
* **Expected Deliverables:**
  - Karakter pemain dapat bergerak ke 8 arah secara halus di keyboard dan layar sentuh.
  - Visual pemain dapat mengganti layer baju/rambut/senjata secara runtime tanpa bug visual.
  - Roll/Dash state berfungsi dengan i-frames awal.
* **Acceptance Criteria:**
  - Tidak ada frame tearing antar layer saat karakter berjalan ke segala arah.
  - Virtual joystick otomatis muncul saat sentuhan layar terdeteksi dan tidak mengganggu area tombol aksi.

---

## Phase 3: World & Exploration

* **Tujuan:** Membangun pipeline level dengan `TileMapLayer`, pengelompokan Y-Sort, pintu gerbang/transisi level, dan sistem interaksi objek lingkungan.
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated test suites: Unit 91/91 PASS, Runtime 78/78 PASS; Total proyek 287/287 assertions PASS tanpa galat)
* **Testing Coverage Breakdown:**
  1. **Automated Unit & Component Tests (`tests/test_phase_3.gd`):** 91 assertions pass (struktur node, bitmask layer, interactable queue, panel dialog modal, input keyboard/touch, routing spawn, spawn ID guard pada transisi ditolak).
  2. **Runtime Integration & Physics Tests (`tests/runtime_validation_phase_3.gd`):** 78 assertions pass (multi-frame `move_and_slide()` collision, corner sliding, recursive Y-sort chain & footprint math, siklus produksi `SceneManager.change_scene_with_spawn()`, pencegahan race condition spawn ID pada pemanggilan ganda dan path tidak valid, pembersihan spawn ID, pencegahan duplikasi instans).
  3. **Manual Visual Tests:** Verifikasi rendering karakter di balik kanopi pohon, di depan batang pohon, di bawah `OverheadLayer`, kelancaran transisi fade, dan keterbacaan teks modal.
  4. **Android Physical-Device Tests:** **PENDING** (Emulasi sensor landscape & sentuh terverifikasi; pengujian hardware fisik smartphone dijadwalkan pada Phase 8).
* **Dependencies:** Phase 1, Phase 2.
* **Daftar Pekerjaan:**
  1. Setup arsitektur level menggunakan `TileMapLayer` bertingkat (GroundLayer, WallDecorationLayer, YSortEntities [SolidObjectsLayer, Player, Interactables], OverheadLayer, WorldBoundaries).
  2. Pengaturan Y-Sort layer pada semua entitas dinamis (pemain, NPC, objek pohon/peti/papan) dengan anchor pivot di alas/kaki.
  3. Pembuatan `InteractionComponent` dan `Interactable` (Area2D layer 8) untuk peti, pintu, papan pengumuman.
  4. Pembuatan `Door` yang terhubung ke `SceneManager.change_scene_with_spawn` untuk perpindahan map/ruangan dengan spawn point.
  5. Setup test level prototype kampus Untidar (`outdoor_test.tscn`, `building_test.tscn`, dan integrasi `main.tscn`).
* **Expected Deliverables:**
  - Template level fungsional dengan tabrakan dinding dan sorting kedalaman yang presisi.
  - Pemain dapat berinteraksi dengan objek dunia via tombol `E` / Touch Interact.
  - Transisi antar level berjalan mulus dengan efek fade-in/fade-out dan penempatan spawn point yang akurat.
* **Acceptance Criteria:**
  - Karakter dapat berjalan di depan dan di belakang pohon/bangunan dengan kedalaman visual yang benar.
  - Pemain tidak tembus dinding atau terjepit di sudut sempit.
  - Objek interaktif menampilkan prompt teks kontekstual dan tombol sentuh bereaksi secara instan.

---

## Phase 4: Combat System

* **Tujuan:** Membangun sistem pertarungan top-down real-time: serangan jarak dekat/jauh, kalkulasi damage/defense, knockback, efek flash darah, dan AI dasar musuh.
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated unit suite 97/97 assertions dan runtime physics suite 47/47 assertions, 100% PASS)
* **Dependencies:** Phase 2 (Character FSM), Phase 3 (World).
* **Daftar Pekerjaan Selesai:**
  1. State `PlayerAttackState` dengan sistem 2-stage combo, timing window (Startup 0.08s, Active 0.12s, Recovery 0.10s), input buffering, dan orientasi hitbox 8 arah.
  2. Matriks 8-layer collision dan faction filtering (`HitboxComponent` & `HurtboxComponent` enum `Faction { PLAYER, ENEMY, NEUTRAL }`):
     - Layer 1: World / Obstacles
     - Layer 2: Player Body (2) [Mask: 17 = 1|16]
     - Layer 3: Player Hurtbox (4) [Mask: 64 = Enemy Hitbox]
     - Layer 4: Player Hitbox (8) [Mask: 32 = Enemy Hurtbox]
     - Layer 5: Enemy Body (16) [Mask: 19 = 1|2|16]
     - Layer 6: Enemy Hurtbox (32) [Mask: 8 = Player Hitbox]
     - Layer 7: Enemy Hitbox (64) [Mask: 4 = Player Hurtbox]
     - Layer 8: Interactables (128)
  3. Pembuatan `scenes/enemy/base_enemy.tscn` & `scripts/enemy/base_enemy.gd` dengan FSM: `EnemyIdleState`, `EnemyChaseState`, `EnemyAttackState`, `EnemyHurtState`.
  4. Sistem reaksi terkena serang: Red Flash tween, knockback physics integratif pada `VelocityComponent` & `move_and_slide()` (zero wall clipping), dan floating combat text via `EventBus.show_floating_text`.
  5. Sinyal kematian single-emission (`EventBus.enemy_defeated`), fade feedback, dan pembersihan aman entitas musuh (`queue_free`).
  6. Pembuatan test arena `scenes/world/combat_arena.tscn` & `scripts/world/combat_arena.gd` terhubung door transition dua arah dengan `outdoor_test.tscn`.
  7. Post-Implementation Audit Fix: Isolasi vektor knockback pada `VelocityComponent` (bebas pencemaran velocity normal pasca collision), integrasi delta fisika di seluruh state, dan penambahan `PlayerHurtState`.
* **Verified Deliverables & Acceptance Criteria:**
  - Pemain dapat menyerang ke 8 arah hadap karakter dengan combo 2 tahap (Stage 1: 15 dmg, 120 kb; Stage 2: 25 dmg, 200 kb).
  - Musuh mendeteksi dan mengejar pemain saat masuk radius aggro (120 px) serta melancarkan serangan telegraphed saat dalam jangkauan (24 px).
  - Friendly fire diblokir oleh collision mask dan filtering faksi.
  - Invulnerability frames (i-frames 0.2s) pada `HurtboxComponent` mencegah damage beruntun instan (anti multi-tick).
  - Knockback tidak menyebabkan clipping atau menembus dinding batas.

---

## Phase 5: Loot & Progression

* **Tujuan:** Mengembangkan sistem inventaris, equipment, drop loot berbobot persentase, dan peningkatan status karakter berbasis resource.
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated unit suite 122/122 assertions dan runtime physics suite 29/29 assertions, 100% PASS)
* **Dependencies:** Phase 4 (Combat System), Phase 1 (Data Resources).
* **Daftar Pekerjaan Selesai:**
  1. Implementasi Resource `ItemData` dan turunan `EquipmentData` (`Weapon`, `Head`, `Body`, `Accessory`) dengan rarity, stacking, dan icon pixel-art terdedikasi.
  2. Sistem `InventoryManager` terpusat: kapasitas 20 slot, stack merging otomatis, penanganan kapasitas parsial, pemindahan & pertukaran slot aman tanpa kehilangan/duplikasi item.
  3. Sistem `EquipmentManager` dengan pertukaran atomic (in-place inventory swap), penolakan aman saat inventaris penuh, sinkronisasi atribut karakter, dan integrasi visual `ModularVisuals`.
  4. Komponen `CharacterStats`: perhitungan dinamis Base Stats + Equipment Bonuses + Allocated Stat Points, pembatasan Max HP, integrasi scaling serangan langsung ke `PlayerAttackState`, dan pertahanan ke `HurtboxComponent`.
  5. Sistem EXP dan Leveling: penambahan EXP saat musuh dikalahkan, level up otomatis (multi-level overflow), formula ambang level adaptif, dan alokasi poin status (+HP, +ATK, +DEF).
  6. Sistem `LootTable` dan `LootDropEntry`: evaluasi probabilitas drop independen dan weighted raffle selection dengan RNG terinjeksi untuk uji deterministik.
  7. Komponen `LootSpawner` dan scene `WorldItem`: animasi floating bobbing, pickup fisik otomatis & interaksi tombol E, proteksi pengambilan ganda (single-pickup lock), dan penolakan aman saat inventaris penuh.
  8. Antarmuka Pengguna `InventoryUI`: panel grid 20 slot, detail barang terpilih, tombol aksi pasang/buang, tampilan slot perlengkapan, EXP bar, display status tempur, tombol alokasi stat point, kompatibel 640x360, serta integrasi tombol sentuh mobile `%InventoryButton`.
* **Verified Deliverables & Acceptance Criteria:**
  - Item dapat dijatuhkan dari musuh yang mati dan dipungut masuk ke inventaris secara mulus.
  - Memasang senjata atau zirah secara langsung dan akurat meningkatkan nilai serang/tahan di hitboxes dan kalkulasi damage pertempuran nyata.
  - Tidak ada duplikasi atau kehilangan item pada seluruh skenario pemindahan, pertukaran, maupun operasi gagal karena inventaris penuh.
  - Seluruh sistem lulus uji regresi 582/582 assertions (100% PASS).

---

## Phase 6: Quest & Dungeon

* **Tujuan:** Mengintegrasikan sistem alur cerita petualangan, dialog NPC bercabang, pelacakan tugas (quest log), dan area dungeon bertingkat.
* **Status Pekerjaan:** **PLANNED**
* **Dependencies:** Phase 3, Phase 4, Phase 5.
* **Daftar Pekerjaan:**
  1. Implementasi Resource `QuestData` (Objective: bunuh musuh, kumpulkan barang, bicara NPC).
  2. Komponen `QuestManager` yang mendengarkan event via `EventBus` (`enemy_defeated`, `item_collected`).
  3. Sistem dialog sederhana dengan nama pembicara, potret wajah, dan teks typewriter.
  4. Logika kunci dan pintu dungeon (mengumpulkan kunci untuk membuka area bos).
  5. Boss entity dengan phase transitions (fase 1 dan fase 2 serang).
* **Expected Deliverables:**
  - NPC dapat memberikan quest, memperbarui progres saat objektif terpenuhi, dan memberikan reward EXP/item.
  - Area dungeon fungsional dengan tantangan mini-boss.
* **Acceptance Criteria:**
  - Progres quest tidak melonjak ganda jika event yang sama terpicu berkali-kali.

---

## Phase 7: UI & Persistence

* **Tujuan:** Merancang antarmuka pengguna (HUD, Inventory UI, Quest Log, Menu Pause, Game Over) dan sistem penyimpanan data (Save/Load).
* **Status Pekerjaan:** **PLANNED**
* **Dependencies:** Phase 1 s/d Phase 6.
* **Daftar Pekerjaan:**
  1. Pembuatan HUD: Bar HP, Bar Stamina, Indikator EXP, Quickslot Potion, Minimap kecil.
  2. Layar antarmuka UI Inventaris dan Equipment dengan drag-and-drop atau touch tap.
  3. Implementasi `DataManager`: Serialisasi status lengkap pemain ke `user://savegame.json`.
  4. Layar Main Menu, Settings (pengaturan volume BGM/SFX), dan Pause Menu.
  5. Fitur cadangan save game teks Base64 untuk pemain Web browser.
* **Expected Deliverables:**
  - Seluruh UI responsif terhadap berbagai rasio layar Android dan Web desktop.
  - Game dapat disimpan, ditutup, dibuka kembali, dan memuat status sebelumnya secara sempurna.
* **Acceptance Criteria:**
  - Data HP, posisi koordinat, quest aktif, dan barang di tas kembali persis seperti saat disimpan.

---

## Phase 8: Deployment & Optimization

* **Tujuan:** Melakukan profil performa, optimasi memori dan draw calls, konfigurasi export Web dan Android, serta build rilis.
* **Status Pekerjaan:** **PLANNED**
* **Dependencies:** Phase 1 s/d Phase 7.
* **Daftar Pekerjaan:**
  1. Profil performa CPU & GPU menggunakan Godot Profiler pada perangkat Android nyata.
  2. Optimasi atlas tekstur dan penghapusan draw call yang tidak perlu.
  3. Konfigurasi `export_presets.cfg` untuk Web (HTML5) dengan template responsif.
  4. Konfigurasi `export_presets.cfg` untuk Android (keystore debug/release, permission, target SDK).
  5. Verifikasi batasan memori WebGL dan penanganan pause saat ponsel menerima panggilan telepon.
* **Expected Deliverables:**
  - Bundle file HTML5 Web yang siap di-host di itch.io atau web server kampus.
  - File APK/AAB yang siap diuji coba di ponsel Android.
* **Acceptance Criteria:**
  - Game stabil pada 60 FPS pada ponsel Android mid-range.
  - Waktu muat awal Web build di bawah 10 detik pada koneksi internet standar.

