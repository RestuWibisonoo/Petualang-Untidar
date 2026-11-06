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
| **Phase 4** | Combat System | **PLANNED** | 4 |
| **Phase 5** | Loot & Progression | **PLANNED** | 5 |
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
* **Status Pekerjaan:** **COMPLETED** (Tervalidasi via automated test suite `tests/test_phase_3.gd`, 69/69 assertions pass; 187/187 total project regression pass)
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
* **Status Pekerjaan:** **PLANNED**
* **Dependencies:** Phase 2 (Character FSM), Phase 3 (World).
* **Daftar Pekerjaan:**
  1. State `PlayerAttackState` dengan timing combo dan aktivasi `HitboxComponent`.
  2. Setup collision layer matriks:
     - Layer 1: World / Obstacles
     - Layer 2: Player Body
     - Layer 3: Player Hurtbox
     - Layer 4: Player Hitbox
     - Layer 5: Enemy Body
     - Layer 6: Enemy Hurtbox
     - Layer 7: Enemy Hitbox
     - Layer 8: Interactables
  3. Pembuatan `BaseEnemy.tscn` dengan FSM: `EnemyIdleState`, `EnemyChaseState`, `EnemyAttackState`, `EnemyHurtState`.
  4. Sistem reaksi terkena serang: Red Flash shader, knockback physics, dan angka damage melayang (*floating combat text*).
  5. Sinyal kematian dan pembersihan entitas musuh.
* **Expected Deliverables:**
  - Pemain dapat menyerang ke arah hadap karakter.
  - Musuh mengejar pemain saat masuk radius aggro dan menyerang.
  - Sistem pertarungan terasa solid dengan umpan balik visual (*game feel* / *juice*).
* **Acceptance Criteria:**
  - Serangan pemain hanya mengenai hurtbox musuh, tidak mengenai diri sendiri atau NPC.
  - Invulnerability frames (i-frames) mencegah damage beruntun instan yang tidak adil bagi pemain.

---

## Phase 5: Loot & Progression

* **Tujuan:** Mengembangkan sistem inventaris, equipment, drop loot berbobot persentase, dan peningkatan status karakter berbasis resource.
* **Status Pekerjaan:** **PLANNED**
* **Dependencies:** Phase 4 (Combat System), Phase 1 (Data Resources).
* **Daftar Pekerjaan:**
  1. Implementasi Resource `ItemData`, `EquipmentData`, dan `CharacterStats`.
  2. Sistem `InventoryManager` (manajemen grid tas, stacking item, batas kapasitas).
  3. Sistem equip item yang secara dinamis memperbarui visual layer di `ModularVisuals` dan mengubah atribut di `CharacterStats`.
  4. Komponen `LootSpawner` yang memunculkan item di tanah dengan efek bouncing sederhana saat musuh dikalahkan.
  5. Sistem EXP, Level Up, dan alokasi poin status.
* **Expected Deliverables:**
  - Item dapat dipungut dari tanah dan masuk ke inventaris.
  - Mengganti senjata atau zirah langsung mengubah tampilan karakter dan daya serang/bertahan.
* **Acceptance Criteria:**
  - Tidak ada duplikasi item saat berpindah slot inventaris.
  - Atribut karakter bertambah dan berkurang secara akurat saat barang dipasang atau dilepas.

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

