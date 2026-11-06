# Technical Decision Log: Petualang Untidar

- **Dokumen:** Catatan Keputusan Arsitektur & Rekayasa Teknis (ADR - Architecture Decision Records)
- **Target Engine:** Godot Engine 4.7.2
- **Terakhir Diperbarui:** 2026-11-06

---

## Ringkasan Keputusan Teknis

| ID | Topik Keputusan | Status | Tanggal |
| :---: | :--- | :---: | :---: |
| **ADR-001** | Pemilihan Game Engine: Godot Engine 4.7.2 | **ADOPTED** | 2026-11-06 |
| **ADR-002** | Bahasa Pemrograman: GDScript 2.0 (Strict Typing) | **ADOPTED** | 2026-11-06 |
| **ADR-003** | Rendering Pipeline: GL Compatibility Renderer | **ADOPTED** | 2026-11-06 |
| **ADR-004** | Target Platform: Web (HTML5) & Android (Mobile) | **ADOPTED** | 2026-11-06 |
| **ADR-005** | Sistem Pergerakan: 8-Directional Discretized Movement | **ADOPTED** | 2026-11-06 |
| **ADR-006** | Kustomisasi Karakter: Modular Synchronized Layering Rig | **ADOPTED** | 2026-11-06 |
| **ADR-007** | Standar Pixel Art: Viewport Scaling & Integer Snapping | **ADOPTED** | 2026-11-06 |
| **ADR-008** | Arsitektur Data: Custom Resources (`.tres`) Berorientasi Tipe | **ADOPTED** | 2026-11-06 |
| **ADR-009** | Pola Jaringan: Single-Player First dengan Decoupled Architecture | **ADOPTED** | 2026-11-06 |
| **ADR-010** | Konvensi Struktur Direktori: Direct Root Modular | **ADOPTED** | 2026-11-06 |
| **ADR-011** | Standar Kanvas Pixel Art Karakter 32x32 & Layout Spritesheet Seragam | **ADOPTED** | 2026-11-06 |
| **ADR-012** | Virtual Touch Joystick & Touch Controls Input Layering | **ADOPTED** | 2026-11-06 |
| **ADR-013** | TileMapLayer Pipeline & 2D Y-Sort Depth Architecture | **ADOPTED** | 2026-11-06 |
| **ADR-014** | Component-Based Interaction System (Layer 8 Matrix) | **ADOPTED** | 2026-11-06 |
| **ADR-015** | Door Transition & Spawn Point Routing via SceneManager | **ADOPTED** | 2026-11-06 |
| **ADR-016** | 8-Layer Combat Collision Matrix & Faction Filtering | **ADOPTED** | 2026-11-06 |
| **ADR-017** | Player 2-Stage Attack Combo, Input Buffering & 8-Directional Orientation | **ADOPTED** | 2026-11-06 |
| **ADR-018** | Hurtbox Single-Authority Invulnerability (I-Frames) & Physics Knockback Integration | **ADOPTED** | 2026-11-06 |
| **ADR-019** | Custom Resources untuk Items, Equipment & Loot Tables | **ADOPTED** | 2026-11-07 |
| **ADR-020** | Inventory Stacking, Atomic Swapping & Capacity Mechanics | **ADOPTED** | 2026-11-07 |
| **ADR-021** | Character Stats Composition & Dynamic Combat Recalculation | **ADOPTED** | 2026-11-07 |
| **ADR-022** | Event-Driven Loot Spawner & Single-Pickup Ground Item Architecture | **ADOPTED** | 2026-11-07 |

---

### ADR-001: Pemilihan Game Engine — Godot Engine 4.7.2

* **Konteks:** Diperlukan game engine 2D yang ringan, tanpa biaya lisensi, memiliki ekosistem node 2D matang, mendukung export Web dan mobile secara stabil, serta didukung oleh toolchain modern.
* **Keputusan:** Menggunakan **Godot Engine 4.7.2**.
* **Alasan Pemilihan:**
  1. Engine 2D kelas satu (*first-class dedicated 2D pipeline*) dengan koordinat pixel terdedikasi.
  2. Ukuran binary runtime sangat kecil (~30–40 MB), ideal untuk Web dan ponsel dengan spesifikasi terbatas.
  3. Menggunakan `TileMapLayer` yang lebih efisien dan modular dibanding Godot 3 atau versi 4 awal.
  4. Integrasi Language Server Protocol (LSP) bawaan yang bekerja mulus dengan IDE modern.
* **Alternatif yang Dipertimbangkan:**
  - *Unity:* Biaya lisensi dan ukuran runtime build WebGL yang sangat besar (~80–150 MB).
  - *Godot 3.5:* Stabil untuk web lama, namun ekosistemnya sudah *deprecated* dan tidak memiliki fitur-fitur GDScript 2.0 modern.
* **Konsekuensi:** Fitur-fitur eksklusif Godot 4.x harus dipelajari dengan disiplin; tidak boleh mencampurkan tutorial lama berbasis Godot 3.

---

### ADR-002: Bahasa Pemrograman — GDScript 2.0 (Strict Typing)

* **Konteks:** Menentukan bahasa scripting utama proyek antara GDScript dan C#.
* **Keputusan:** Menggunakan **GDScript 2.0 dengan Static Typing penuh** (mewajibkan type hint `: int`, `: Vector2`, `-> void`).
* **Alasan Pemilihan:**
  1. Dukungan Web Export (HTML5/Wasm) untuk C#/.NET di Godot 4 masih memiliki batasan kompatibilitas dan ukuran payload besar.
  2. GDScript terintegrasi secara *native* ke dalam engine tanpa overhead JIT/CLR pada runtime Android.
  3. Type hinting di Godot 4.x memberikan performa eksekusi lebih cepat via bytecode optimization dan mencegah runtime null pointer exception.
* **Alternatif yang Dipertimbangkan:**
  - *C# (.NET):* Ekosistem kaya, tetapi compile time lebih lambat dan dukungan Web export Godot 4 belum semulus GDScript.
  - *GDExtension (C++/Rust):* Over-engineering untuk kebutuhan 2D Top-down RPG skala proyek ini.
* **Konsekuensi:** Seluruh kontributor wajib mematuhi standar penulisan kode strictly-typed.

---

### ADR-003: Rendering Pipeline — GL Compatibility Renderer

* **Konteks:** Godot 4 menyediakan tiga metode rendering: Forward+ (Vulkan), Mobile (Vulkan/Direct3D12), dan GL Compatibility (OpenGL ES 3.0 / WebGL 2.0).
* **Keputusan:** Menggunakan **`gl_compatibility`** baik untuk desktop, mobile, maupun web.
* **Alasan Pemilihan:**
  1. Forward+ dan Mobile tidak didukung secara penuh pada platform WebGL browser.
  2. Kompatibilitas 99% pada perangkat Android lawas maupun baru tanpa risiko driver crash pada chip GPU Mali atau Adreno generasi lama.
  3. Waktu *shader precompilation* hampir instan; tidak ada lag *stuttering* saat game pertama kali dibuka di browser.
* **Alternatif yang Dipertimbangkan:**
  - *Mobile Renderer (Vulkan):* Memiliki fitur pencahayaan lebih kompleks, tetapi waktu startup lambat dan Web export tidak stabil.
* **Konsekuensi:** Tidak bisa menggunakan Compute Shaders tingkat lanjut (tidak dibutuhkan pada game 2D Pixel Art).

---

### ADR-004: Target Platform — Web (HTML5) & Android (Mobile)

* **Konteks:** Game ditargetkan agar dapat dimainkan mahasiswa dan publik langsung melalui peramban web (itch.io / website kampus) maupun diunduh di smartphone Android.
* **Keputusan:** Menjadikan Web dan Android sebagai prioritas arsitektur sejak hari pertama.
* **Alasan Pemilihan:** Aksesibilitas maksimal bagi audiens target tanpa mewajibkan PC gaming berkartu grafis tinggi.
* **Konsekuensi:**
  - Game harus dirancang murni *Single-Threaded* agar tidak memicu isu `SharedArrayBuffer` pada server hosting web biasa.
  - Wajib menyediakan kontrol sentuh (*Virtual Joystick*) yang tersembunyi secara otomatis saat dimainkan di PC.
  - UI wajib memiliki fitur adaptasi *Safe Area / Display Cutout* (notch layar HP).

---

### ADR-005: Sistem Pergerakan — 8-Directional Discretized Movement

* **Konteks:** Menentukan gaya pergerakan karakter top-down: 4 arah (Zelda klasik), 8 arah diskrit, atau rotasi bebas 360 derajat analog.
* **Keputusan:** Menggunakan **8-Directional Movement**.
* **Alasan Pemilihan:**
  1. Memberikan fleksibilitas manuver pertempuran diagonal tanpa merusak proporsi gambar pixel art.
  2. Rotasi bebas 360° pada sprite pixel art akan menyebabkan *pixel rotation shimmering* (sudut pixel terdistorsi secara rotasional jika tidak menggunakan pre-rendered angles).
  3. Cocok dengan sistem combo serang dan roll/dash top-down.
* **Alternatif yang Dipertimbangkan:**
  - *4-Direction Movement:* Terlalu kaku untuk aksi real-time modern.
  - *Free 360° Movement:* Membutuhkan 3D model yang di-render pixelate atau menyebabkan gambar sprite berputar secara jelek.
* **Konsekuensi:** Aset animasi memerlukan setidaknya 4 arah utama (`down`, `up`, `right`, `left`) dengan opsi interpolasi/mirroring untuk 4 arah diagonal (`down_right`, `down_left`, `up_right`, `up_left`).

---

### ADR-006: Kustomisasi Karakter — Modular Synchronized Layering Rig

* **Konteks:** Pemain harus dapat mengkustomisasi tubuh, rambut, pakaian, zirah, aksesoris, dan senjata.
* **Keputusan:** Menggunakan **Modular Layering Rig** yang disinkronkan oleh 1 master `AnimationPlayer`.
* **Alasan Pemilihan:**
  1. *Pre-rendered sprite sheet per kombinasi* tidak memungkinkan karena akan membutuhkan jutaan file sprite unik (kombinasi matematika: $Body \times Hair \times Clothes \times Armor \times Weapon$).
  2. Dengan memisahkan layer menjadi 10 node `Sprite2D` bertumpuk yang membaca spritesheet bergrid frame seragam, 1 baris timeline `AnimationPlayer` dapat memutar seluruh pakaian secara sinkron tanpa jeda.
* **Alternatif yang Dipertimbangkan:**
  - *Skeletal 2D (Spine/Bone2D):* Menghasilkan distorsi melar (*stretching*) yang merusak estetika pixel art autentik.
* **Konsekuensi:** Seluruh artist/aset pixel art wajib mematuhi standarisasi kanvas dan posisi poros (*pivot*) yang identik.

---

### ADR-007: Standar Pixel Art — Viewport Scaling & Integer Snapping

* **Konteks:** Game pixel art sangat rentan terhadap distorsi visual jika dijalankan pada resolusi layar yang berbeda dari resolusi desain aslinya.
* **Keputusan:** Menetapkan standar:
  - Base Viewport Resolution: **`640x360`** (Rasio 16:9, kelipatan 1080p dan 720p).
  - Stretch Mode: `viewport`, Stretch Aspect: `keep`.
  - Texture Filter Default: `Nearest` (`0`).
  - 2D Pixel Snap: `snap_2d_transforms_to_pixel = true`, `snap_2d_vertices_to_pixel = true`.
* **Alasan Pemilihan:**
  - `640x360` diskalakan tepat 2x ke 720p (HD), 3x ke 1080p (FHD), 4x ke 1440p (QHD), dan 6x ke 4K (UHD) secara *integer scale* sempurna tanpa distorsi.
  - Mencegah garis batas pixel berkedip (*shimmering*) saat kamera bergeser secara halus.
* **Status:** **ADOPTED (Diimplementasikan pada Phase 1).**

---

### ADR-008: Arsitektur Data — Custom Resources (`.tres`) Berorientasi Tipe

* **Konteks:** Pengelolaan data item, statistik musuh, equipment, dan quest.
* **Keputusan:** Menggunakan **Godot Custom Resource (`extends Resource`)**.
* **Alasan Pemilihan:**
  1. Terintegrasi langsung dengan editor inspector Godot (memudahkan game designer mengedit statistik tanpa menyentuh kode).
  2. Sangat cepat dalam proses serialisasi dan deserialisasi bawaan engine.
  3. Memiliki type-safety penuh (`ItemData`, `EquipmentData`, `CharacterStats`).
* **Alternatif yang Dipertimbangkan:**
  - *Hardcoded Dictionary dalam script:* Rentan typo pada string key, tidak ada validasi tipe.
  - *SQLite Database:* Menambah dependensi library eksternal yang memperumit ekspor WebGL.
* **Konsekuensi:** Seluruh data baru harus dibuat melalui file resource `.tres`.

---

### ADR-009: Pola Jaringan — Single-Player First dengan Decoupled Architecture

* **Konteks:** Ruang lingkup saat ini adalah petualangan solo, namun ada pertimbangan ekspansi co-op / multiplayer di masa mendatang.
* **Keputusan:** Membangun game dengan arsitektur **Single-Player First**, namun menggunakan pola *Decoupled State & Event-Driven* yang memisahkan logika dari rendering.
* **Alasan Pemilihan:**
  1. Membangun multiplayer sejak awal secara prematur akan melipatgandakan kompleksitas kode, waktu pengerjaan, dan biaya server yang belum tentu dibutuhkan saat peluncuran awal.
  2. Dengan memisahkan input controller dari entity, di masa depan input remote (RPC / Network) dapat dengan mudah dipasangkan ke entitas tanpa merombak sistem pergerakan dan pertarungan.
* **Konsekuensi:** Tidak ada kode sinkronisasi jaringan yang ditulis pada fase-fase awal.

---

### ADR-010: Konvensi Struktur Direktori — Direct Root Modular

* **Konteks:** Menentukan struktur root direktori apakah menggunakan subfolder pembungkus `src/` atau struktur modular root langsung (`scenes/`, `scripts/`, `assets/`, `resources/`, `docs/`).
* **Keputusan:** Menggunakan **Direct Root Modular** (`scenes/`, `scripts/`, `assets/`, `resources/`, `docs/`).
* **Alasan Pemilihan:**
  1. Format standar engine Godot yang paling natural; path resource menjadi lebih ringkas (misal: `res://scenes/main/main.tscn` dibanding `res://src/scenes/main/main.tscn`).
  2. Memisahkan berkas skrip murni (`scripts/`) dari scene tampilan (`scenes/`) dan data (`resources/`) secara tegas tanpa kedalaman folder yang berlebihan.
  3. Mempermudah navigasi di FileSystem dock Godot Editor.
* **Alternatif yang Dipertimbangkan:**
  - *Nested `src/` structure:* Baik untuk proyek C++/Web tradisional, namun menambah kedalaman path yang tidak perlu pada ekosistem resource Godot.
* **Konsekuensi:** Seluruh import path dan instansiasi scene mengacu pada struktur root tanpa `src/`.

---

### ADR-011: Standar Kanvas Pixel Art Karakter 32x32 & Layout Spritesheet Seragam

* **Konteks:** Menentukan ukuran kanvas per frame untuk sistem kustomisasi modular 10 layer karakter agar proporsional pada viewport 640x360.
* **Keputusan:** Menggunakan **Kanvas 32x32 piksel per frame**, grid 4 kolom × 4 baris (total sheet 128x128 piksel), dengan pivot bottom-center pada `(16, 28)`.
* **Alasan Pemilihan:**
  1. Pada resolusi 640x360, karakter setinggi ~26px menempati ~7.2% tinggi layar, memberikan bidang pandang eksplorasi luas khas top-down RPG 16-bit klasik.
  2. Grid 4x4 (Down, Up, Right, Left) memungkinkan 1 `AnimationPlayer` memutar seluruh 10 layer tanpa pergeseran frame (*frame tearing*).
  3. Menghemat konsumsi memori GPU pada platform Web dan Android low-end dibanding ukuran kanvas 48x48 atau 64x64.
* **Konsekuensi:** Seluruh desainer grafis dan artis pixel art wajib mengikuti template grid 128x128 yang identik.

---

### ADR-012: Virtual Touch Joystick & Touch Controls Input Layering

* **Konteks:** Pemain mobile (Android) dan web browser berbasis touchscreen membutuhkan kendali sentuh intuitif tanpa mengganggu input fisik keyboard/gamepad pada desktop.
* **Keputusan:** Mengimplementasikan **TouchControls pada CanvasLayer independen (Layer 10)** dengan `TouchVirtualJoystick` yang dinamis mendeteksi ketersediaan layar sentuh (`DisplayServer.is_touchscreen_available()`).
* **Alasan Pemilihan:**
  1. Input sentuh menyuntikkan vektor ke metode `set_touch_input()` pada Player secara aman tanpa menimpa (`overwrite`) input action keyboard/gamepad.
  2. Auto-hide otomatis menyembunyikan kontrol sentuh saat game dimainkan pada PC desktop berkursor mouse murni.
  3. Memiliki deadzone dan normalisasi bawaan untuk pergerakan halus ke segala arah.
* **Konsekuensi:** Komponen UI touch controls harus selalu diinstansiasi pada scene atau viewport yang menampung entitas pemain.

---

### ADR-013: TileMapLayer Pipeline & 2D Y-Sort Depth Architecture

* **Konteks:** Menentukan arsitektur level 2D, pemisahan lapisan visual, dan penyusunan kedalaman (*depth sorting*) antara karakter pemain dan objek lingkungan (pohon, bangunan, peti) di Godot 4.7.
* **Keputusan:** Menggunakan node modern **`TileMapLayer`** dengan struktur layer 4-tingkat:
  1. `GroundLayer` (Z-index: 0, tanpa tabrakan).
  2. `WallDecorationLayer` (Z-index: 0, dekorasi lantai/dinding bawah).
  3. `YSortEntities` (`Node2D`, `y_sort_enabled = true`):
     - `SolidObjectsLayer` (`TileMapLayer`, `y_sort_enabled = true`, Collision Layer 1).
     - `Player` (`CharacterBody2D`, anchor pivot di `(0, 0)`, capsule feet di `(0, 8)`).
     - `Interactables` (`Node2D`, `y_sort_enabled = true`).
  4. `OverheadLayer` (`TileMapLayer`, Z-index: 5, atap/kanopi di luar Y-Sort).
* **Alasan Pemilihan:**
  1. Node `TileMap` lama telah dideprecated di Godot 4.3+ demi arsitektur node mandiri `TileMapLayer` yang lebih modular dan berperforma tinggi.
  2. Menempatkan semua entitas dinamis dan rintangan solid di dalam satu induk `YSortEntities` memastikan sorting matematis akurat: karakter di Y < objek tampil di belakang, dan di Y > objek tampil di depan.
  3. Kanopi pohon dan atap bangunan diberi Z-Index 5 di luar YSortEntities agar selalu menutupi karakter yang berjalan di bawahnya tanpa memicu tearing visual.
* **Konsekuensi:** Semua scene objek prop (pohon, batu, bangunan) wajib memiliki pivot/origin `(0, 0)` di dasar kaki atau alas tabrakan fisika.

---

### ADR-014: Component-Based Interaction System (Layer 8 Matrix)

* **Konteks:** Pemain perlu mendeteksi dan berinteraksi dengan berbagai objek lingkungan (peti harta, papan pengumuman, pintu transisi) baik melalui tombol keyboard (`E`) maupun tombol sentuh mobile (`InteractButton`).
* **Keputusan:** Mengimplementasikan pola kontrak komponen Area2D terpisah:
  - **`Interactable` (`Area2D`):** Ditempatkan pada objek dunia. Dikonfigurasi pada **Collision Layer 8 (Value 128, Mask 0)** dan terdaftar dalam grup `&"interactable"`.
  - **`InteractionComponent` (`Area2D`):** Menempel pada Player. Dikonfigurasi pada **Collision Layer 0 (Mask Layer 8: 128)**.
* **Alasan Pemilihan:**
  1. Memisahkan fisika dunia (Layer 1) dan hitbox combat (Layer 3-7) dari deteksi interaksi (Layer 8) menghilangkan interferensi sinyal tabrakan.
  2. `InteractionComponent` mengelola kandidat interaksi terdekat (*closest target*) menggunakan perbandingan jarak Euclidean kuadrat (`distance_squared_to`), mencegah kalkulasi akar kuadrat yang membebani CPU.
  3. Mendukung reaktivitas instan via sinyal `availability_changed` saat sebuah objek terkunci atau sudah dibuka.
* **Konsekuensi:** Semua objek yang dapat berinteraksi wajib memiliki subnode `Interactable` dengan layer 8 aktif.

---

### ADR-015: Door Transition & Spawn Point Routing via SceneManager

* **Konteks:** Menghubungkan eksplorasi antar-scene (halaman luar kampus dan interior gedung) dengan titik kemunculan (*spawn point*) yang presisi dan transisi visual mulus.
* **Keputusan:** Memperluas `SceneManager` dengan method **`change_scene_with_spawn(target_path, spawn_id, with_fade, duration)`** dan `WorldBase._handle_spawn_point()`.
* **Alasan Pemilihan:**
  1. Menghindari ketergantungan erat (*tight coupling*) antar scene: scene pintu hanya perlu mendeklarasikan `target_scene_path: String` dan `target_spawn_id: StringName`.
  2. Level controller (`WorldBase`) secara otomatis memposisikan `Player` ke node `Marker2D` yang cocok di dalam penampung `SpawnPoints` saat scene dimuat.
  3. Layar fade-to-black dari `SceneManager` menyembunyikan frame perpindahan posisi karakter secara elegan.
* **Konsekuensi:** Setiap scene level yang mendukung transisi wajib memiliki node `SpawnPoints` berisi minimal satu `Marker2D` bernama `default`.

---

### ADR-016: 8-Layer Combat Collision Matrix & Faction Filtering

* **Konteks:** Sistem combat memerlukan pemisahan fisik yang ketat antara tubuh karakter/musuh, area serang (hitbox), dan area terima serang (hurtbox) agar tidak terjadi friendly fire, self-damage, atau overlap tabrakan fisik dengan kalkulasi serangan.
* **Keputusan:** Menerapkan matriks 8-layer diskrit dan enumerasi faksi (`Faction { PLAYER = 0, ENEMY = 1, NEUTRAL = 2 }`):
  1. **Layer 1: World (1):** Rintangan statis, dinding batas, dan dekorasi solid.
  2. **Layer 2: Player Body (2) [Mask: 17 = World 1 + Enemy Body 16]:** Tubuh fisik pemain.
  3. **Layer 3: Player Hurtbox (4) [Mask: 64 = Enemy Hitbox]:** Area terima serang pemain.
  4. **Layer 4: Player Hitbox (8) [Mask: 32 = Enemy Hurtbox]:** Area serang tebasan senjata pemain.
  5. **Layer 5: Enemy Body (16) [Mask: 19 = World 1 + Player Body 2 + Enemy Body 16]:** Tubuh fisik musuh.
  6. **Layer 6: Enemy Hurtbox (32) [Mask: 8 = Player Hitbox]:** Area terima serang musuh.
  7. **Layer 7: Enemy Hitbox (64) [Mask: 4 = Player Hurtbox]:** Area serang musuh.
  8. **Layer 8: Interactables (128):** Objek interaktif dunia.
* **Alasan Pemilihan:**
  1. Pemisahan layer fisika di level engine (Godot Physics Server) memangkas kalkulasi tabrakan yang tidak relevan secara optimal (zero CPU overhead untuk pasangan non-mask).
  2. Faction filtering level komponen memastikan fleksibilitas masa depan jika ada status faksi dinamis (misal: minion yang dikontrol atau status confusio/berserk).
* **Konsekuensi:** Setiap entitas bersenjata wajib mengonfigurasi layer dan mask sesuai spesifikasi matriks dan menentukan enum faksi pada `HitboxComponent` dan `HurtboxComponent`.

---

### ADR-017: Player 2-Stage Attack Combo, Input Buffering & 8-Directional Orientation

* **Konteks:** Pemain membutuhkan kontrol serangan aksi yang responsif, berbobot, dan mengalir alami dari pergerakan 8 arah, dengan kemampuan merangkai combo tanpa menuntut presisi tombol berbingkai tunggal (*frame-perfect*).
* **Keputusan:** Mengimplementasikan **`PlayerAttackState`** dengan sistem combo 2 tahap, pembagian jendela waktu per serangan (Startup 0.08s, Active 0.12s, Recovery 0.10s), input buffering tombol serang, dan orientasi hitbox 8 arah.
* **Alasan Pemilihan:**
  1. Pembagian jendela waktu (startup/active/recovery) memberikan bobot tebasan senjata pixel-art yang memuaskan dan telegraphed.
  2. Input buffering selama active/recovery window memungkinkan pemain menekan tombol serang kedua sebelum animasi selesai, lalu engine mengeksekusi serangan lanjutan secara mulus (Stage 2: 25 damage, 200 knockback vs Stage 1: 15 damage, 120 knockback).
  3. `PlayerAttackState` mendiselerasi pergerakan tubuh namun tetap memproses physics slide saat menerima dorongan luar.
* **Konsekuensi:** `ModularVisuals` memutar animasi tebasan sesuai arah hadap (`attack_down`, `attack_up`, `attack_left`, `attack_right`) dengan fallback terisolasi jika aset frame visual tertentu belum tersedia.

---

### ADR-018: Hurtbox Single-Authority Invulnerability (I-Frames) & Physics Knockback Integration

* **Konteks:** Mencegah bug multi-tick damage di mana satu ayunan tebasan mengenai musuh berkali-kali dalam beberapa frame berturut-turut, serta mencegah dorongan knockback menembus dinding batas (*wall clipping*).
* **Keputusan:**
  1. Menjadikan **`HurtboxComponent`** sebagai otoritas tunggal status kekebalan pasca-serang (*invulnerability frames / I-frames*). Status I-frames Hurtbox disinkronisasikan ke `HealthComponent.is_invulnerable`.
  2. `HitboxComponent` menyimpan riwayat target yang sudah dikenai dalam ayunan aktif (`_hit_targets: Array[Area2D]`) dan di-reset pada setiap tebasan baru.
  3. Impuls knockback dikelola melalui **`VelocityComponent.apply_knockback()`** dan diintegrasikan langsung ke dalam `CharacterBody2D.velocity` sebelum `move_and_slide()` dieksekusi.
* **Alasan Pemilihan:**
  1. Mengintegrasikan knockback ke dalam `move_and_slide()` memastikan algoritma deteksi rintangan bawaan engine menghentikan dorongan tepat di permukaan dinding (100% bebas bug tembus tembok).
  2. Menempatkan logika I-frames pada hurtbox mencegah exploit pergantian senjata atau pemanggilan serangan ganda yang menimpa kalkulasi kekebalan target.
* **Konsekuensi:** Durasi kekebalan (`invulnerability_duration`) dan gesekan peluruhan knockback (`knockback_friction`) harus dituning per tipe entitas (default 0.2s dan 800.0 px/s²).

---

### ADR-019: Custom Resources untuk Items, Equipment & Loot Tables

* **Konteks:** Sistem loot, inventaris, dan perlengkapan memerlukan struktur data yang modular, dapat diedit via Godot Inspector, type-safe, dan dapat diserialisasikan ke format text (`.tres`).
* **Keputusan:** Mengimplementasikan hierarki Godot Custom Resource:
  1. `ItemData` (`scripts/resources/item_data.gd`): Properti dasar item (`item_id`, `item_name`, `description`, `icon`, `item_type`, `rarity`, `max_stack`, `sell_value`, `is_stackable`).
  2. `EquipmentData` (`scripts/resources/equipment_data.gd`): Turunan `ItemData` dengan atribut perlengkapan (`equipment_slot`, `attack_bonus`, `defense_bonus`, `health_bonus`, `movement_speed_bonus`, `visual_layer`).
  3. `LootDropEntry` (`scripts/resources/loot_drop_entry.gd`) & `LootTable` (`scripts/resources/loot_table.gd`): Mendukung probabilitas mandiri (*independent chance*) dan kolam drop berbobot (*weighted random pool*) dengan injeksi RNG untuk pengujian deterministik.
* **Alasan Pemilihan:**
  1. Custom Resource (`.tres`) memisahkan data gameplay murni dari hierarki scene, menghemat memori runtime dan memungkinkan hot-reloading di editor.
  2. Pewarisan `EquipmentData extends ItemData` mengizinkan slot inventaris menerima item jenis apa pun secara transparan tanpa casting runtime yang rentan error.
  3. Format teks `.tres` mempermudah tracking perubahan file di Git (human-readable diffs).
* **Konsekuensi:** Semua item, senjata, zirah, dan tabel loot dibuat dan disimpan sebagai `.tres` di direktori `resources/`.

---

### ADR-020: Inventory Stacking, Atomic Swapping & Capacity Mechanics

* **Konteks:** Manajemen inventaris (kapasitas 20 slot) harus menjamin integritas data 100% bebas item loss atau item duplication saat pemindahan, penukaran, penambahan parsial, maupun penggabungan stack.
* **Keputusan:** Menggunakan `InventorySlot` berbasis `RefCounted` dan `InventoryManager` dengan arsitektur transaksi atomik:
  1. Operasi penambahan (`add_item`) mengutamakan pengisian stack sejenis hingga `max_stack` sebelum mengonsumsi slot kosong baru.
  2. Mendukung *partial insertion*: item disisipkan sebanyak sisa ruang yang tersedia, dan kuantitas overflow dikembalikan tanpa membuang item.
  3. Penukaran dan pemindahan slot (`swap_slots`, `move_slot`) dijalankan secara atomik dalam 1 frame tanpa risiko item hilang di tengah proses.
  4. Snapshot data diekspor sebagai deep-copy (`get_slots_snapshot()`) untuk melindungi internal inventory dari manipulasi eksternal UI.
* **Alasan Pemilihan:**
  1. Menghilangkan celah duplikasi item (*item duplication exploit*) yang biasa terjadi pada manipulasi inventaris asinkron.
  2. Menjamin batas kapasitas tetap (20 slot) dipatuhi secara ketat di semua skenario transaksi.
* **Konsekuensi:** Seluruh antarmuka UI dan gameplay wajib berinteraksi dengan inventaris melalui API publik `InventoryManager`.

---

### ADR-021: Character Stats Composition & Dynamic Combat Recalculation

* **Konteks:** Statistik tempur karakter (HP, Attack, Defense, Movement Speed) dipengaruhi oleh base level stats, bonus equipment yang dikenakan, dan alokasi stat points pemain saat naik level.
* **Keputusan:** Menggunakan `CharacterStats` terpusat yang menghitung total stat secara dinamis:
  - $\text{Stat Total} = \text{Base} + \text{Equipment Bonus} + \text{Allocated Bonus}$
  - Mengintegrasikan stat total ke `PlayerAttackState` (skalasi damage combo), `HurtboxComponent` (reduksi damage via defense), dan `VelocityComponent` (skalasi move speed).
  - Mekanisme anti-exploit Max HP clamping: pelepasan armor mengurangi current HP jika melebihi batas baru, namun pemakaian armor tidak langsung menyembuhkan HP pemain (*no auto-heal exploit*).
  - Formula kurva level progresif: $\text{Required EXP} = \text{int}(100 \times \text{level}^{1.2})$ dengan dukungan multi-level overflow dan alokasi 3 stat points per level.
* **Alasan Pemilihan:**
  1. Menghindari duplikasi kalkulasi stat di berbagai skrip combat.
  2. Mencegah exploit "equip armor to heal" yang umum pada game RPG.
  3. Menjamin progresivitas level yang seimbang dan fleksibilitas build karakter.
* **Konsekuensi:** Seluruh pembacaan status tempur pemain diarahkan ke `CharacterStats`.

---

### ADR-022: Event-Driven Loot Spawner & Single-Pickup Ground Item Architecture

* **Konteks:** Ketika musuh dikalahkan, sistem harus mendistribusikan EXP dan memunculkan item drop di lantai tanpa menyebabkan race condition atau query collision flush error pada Godot physics engine.
* **Keputusan:** Mengimplementasikan arsitektur decoupled:
  1. Musuh memancarkan `EventBus.enemy_defeated_at(enemy_id, position, exp_reward, loot_table)`.
  2. `LootSpawner` di level menangani sinyal, memberikan EXP secara otomatis ke `CharacterStats`, dan mengevaluasi `LootTable`.
  3. Drop item diinstansiasi sebagai `WorldItem` (`Area2D` di Layer 8) secara `call_deferred("add_child", item)` untuk menghindari error `Can't change this state while flushing queries`.
  4. `WorldItem` memiliki single-pickup lock (`_is_collected`) dan ground rejection: jika inventaris pemain penuh, item tetap aman di lantai dan tidak hilang.
* **Alasan Pemilihan:**
  1. Memisahkan siklus hidup musuh dari proses spawn loot; musuh dapat langsung di-`queue_free()` tanpa menunggu animasi drop item.
  2. Ground rejection melindungi barang pemain dari hilang sia-sia akibat inventaris penuh.
  3. Single-pickup lock mencegah pengambilan ganda saat area overlap terpicu beruntun.
* **Konsekuensi:** Semua scene musuh harus memiliki properti `exp_reward` dan referensi `loot_table`.


