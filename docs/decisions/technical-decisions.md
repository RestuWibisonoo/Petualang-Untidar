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

