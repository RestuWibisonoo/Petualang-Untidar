# Project Audit Report: Petualang Untidar

- **Tanggal Audit:** 2026-11-06
- **Status:** COMPLETED
- **Auditor:** Senior Godot Game Architect & Technical Lead
- **Target Platform:** Web (HTML5/WebGL 2.0) & Android (GLES3/APK)
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable)

---

## 1. Task Overview

Melakukan audit menyeluruh terhadap repositori proyek *Petualang Untidar* untuk mengevaluasi kesiapan teknis sebelum tahap pengembangan dimulai. Audit mencakup pemeriksaan engine, konfigurasi proyek (`project.godot`), rendering pipeline, sistem display/resolusi, input mapping, kesiapan platform target (Web & Android), struktur direktori, serta integritas toolchain/IDE (Godot Tools LSP & Antigravity IDE).

---

## 2. Objective

1. Mengidentifikasi kondisi awal codebase dan aset yang ada.
2. Memeriksa kesesuaian konfigurasi engine untuk target Web dan Android.
3. Menilai kompatibilitas untuk game 2D Pixel Art Top-Down.
4. Memvalidasi sambungan toolchain antara Godot Engine dan Antigravity IDE.
5. Mendokumentasikan seluruh temuan, risiko, dan rekomendasi perbaikan sebelum menyusun arsitektur dan fondasi gameplay.

---

## 3. Files Inspected & Verified

| File / Komponen | Lokasi Path | Status Saat Ini |
| :--- | :--- | :--- |
| `project.godot` | `/Users/restuwibisono/Documents/Project/petualang-untidar/project.godot` | Ada (30 baris konfigurasi dasar) |
| `scripts/main.gd` | `/Users/restuwibisono/Documents/Project/petualang-untidar/scripts/main.gd` | Ada (Script template bawaan, belum terpakai) |
| `icon.svg` | `/Users/restuwibisono/Documents/Project/petualang-untidar/icon.svg` | Ada (Ikon standar Godot) |
| Editor Settings | `~/Library/Application Support/Godot/editor_settings-4.7.tres` | Ada (Terkonfigurasi untuk Antigravity) |
| Symlink Godot CLI | `~/.local/bin/godot` | Terhubung ke `/Applications/Godot.app/Contents/MacOS/Godot` |
| IDE Settings | `~/Library/Application Support/Antigravity/User/settings.json` | Terkonfigurasi untuk LSP Godot (port 6005) |

---

## 4. Detailed Audit Findings

### 4.1 Kondisi Proyek & Repositori
* Proyek berada dalam kondisi inisiasi awal (*blank project*).
* Belum ada version control Git yang diinisialisasi pada repositori lokal ini (`Not a git repo`).
* Belum ada scene utama yang didaftarkan ke `application/run/main_scene`.
* File `scripts/main.gd` hanya berisi method stub `_ready()` dan `_process()` kosong.

### 4.2 Engine & Versi
* **Versi Engine:** Godot Engine 4.7.2.
* **Config Version:** `config_version=5` (Godot 4.x standard).
* **Fitur Terdaftar:** `PackedStringArray("4.7", "GL Compatibility")`.

### 4.3 Evaluasi Konfigurasi `project.godot`

#### A. Renderer Pipeline
```ini
[rendering]
rendering_device/driver.windows="d3d12"
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```
* **Status:** **OPTIMAL untuk Web & Android.**
* **Analisis:** Penggunaan `gl_compatibility` (OpenGL ES 3.0 di Android / WebGL 2.0 di Web) adalah pilihan terbaik. Renderer `Forward+` dan `Mobile` berbasis Vulkan memiliki kelemahan fatal pada platform Web (tidak didukung atau memiliki kompilasi shader pipeline yang sangat lambat) serta performa berat pada perangkat Android low-to-mid range.

#### B. Display & Resolusi
```ini
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```
* **Status:** **PERLU PENYESUAIAN (Defisiensi Pixel Art).**
* **Analisis Masalah:**
  1. Belum ada resolusi viewport dasar (`display/window/size/viewport_width` dan `viewport_height`).
  2. Mode `canvas_items` dengan aspect `expand` pada game pixel art menyebabkan distorsi piksel (*non-integer pixel scaling*, *pixel shimmering*, dan garis piksel tampak tidak konsisten ketika ukuran layar berubah).
  3. Belum diaktifkannya pixel snap menyebabkan artefak visual (*sub-pixel jitter*) saat kamera atau karakter bergerak.
* **Tindakan yang Diperlukan:** Ubah ke `stretch/mode="viewport"`, `stretch/aspect="keep"`, tentukan resolusi dasar (direkomendasikan `640x360` atau `480x270`), serta aktifkan `rendering/2d/snap/snap_2d_transforms_to_pixel=true` dan `snap_2d_vertices_to_pixel=true`.

#### C. Texture Filtering
* **Status:** **BELUM DIKONFIGURASI (Default Linear).**
* **Analisis Masalah:** Secara default, Godot menggunakan filter linear yang membuat tekstur pixel art tampak buram (*blurry*).
* **Tindakan yang Diperlukan:** Daftarkan parameter `textures/canvas_textures/default_texture_filter=0` (`Nearest`) pada `project.godot`.

#### D. Input Mapping
* **Status:** **KOSONG.**
* **Analisis:** Bagian `[input]` belum ada sama sekali. Belum ada definisi aksi untuk pergerakan 8 arah (`move_up`, `move_down`, `move_left`, `move_right`), interaksi (`interact`), pertarungan (`attack`), dash/roll (`roll`), maupun navigasi menu/pause (`pause`, `inventory`).

#### E. Physics Engine
```ini
[physics]
3d/physics_engine="Jolt Physics"
```
* **Status:** **REDUNDAN.**
* **Analisis:** Game ini adalah 2D Top-Down murni. Konfigurasi 3D physics Jolt tidak membahayakan eksekusi 2D (`GodotPhysics2D`), namun pada saat export sebaiknya fitur 3D dinonaktifkan untuk memperkecil ukuran bundle binary Web dan APK Android.

---

## 5. Kesiapan Platform: Web & Android

### 5.1 Target Web (HTML5 / Wasm)
1. **Thread Limit:** Web export standar Godot 4 berjalan pada *Single Thread* kecuali server web menyajikan header `Cross-Origin-Opener-Policy: same-origin` dan `Cross-Origin-Embedder-Policy: require-corp` (COOP/COEP).
   * *Status Teknis:* Arsitektur game wajib dirancang murni *Single-Threaded* tanpa ketergantungan pada worker thread manual.
2. **Audio Autoplay Lock:** Browser memblokir audio sebelum adanya input pointer/touch pertama dari pengguna.
   * *Status Teknis:* `AudioManager` wajib memiliki mekanisme deteksi *first user gesture* sebelum memutar BGM.
3. **Penyimpanan Lokal:** File `user://` pada browser disimpan di IndexedDB.
   * *Status Teknis:* Data save game aman untuk sesi normal, namun dapat hilang jika cache browser dibersihkan oleh pengguna. Direkomendasikan menyediakan fitur export/import save string (Base64) di kemudian hari.

### 5.2 Target Android
1. **Input Touchscreen:** Belum ada sistem virtual control.
   * *Status Teknis:* Membutuhkan implementasi *Dynamic Floating Virtual Joystick* dan tombol aksi sentuh yang mengirim event ke action input yang sama dengan keyboard.
2. **Fragmentasi Aspek Rasio & Notches (Safe Area):**
   * *Status Teknis:* Layar Android memiliki variasi rasio mulai dari 16:9 hingga 21:9. UI CanvasLayer wajib menggunakan *Anchor Presets* dan mendeteksi display cutout / safe area margin agar HUD tidak terpotong kamera depan ponsel.
3. **Orientasi Layar:**
   * *Status Teknis:* Belum dikonfigurasi. Perlu diset ke Landscape (`display/window/handheld/orientation="sensor_landscape"`).

---

## 6. Status Integrasi Toolchain & IDE

* **Godot Tools Extension:** Versi `2.7.1` terverifikasi aktif di Antigravity IDE (`geequlim.godot-tools`).
* **GDScript Language Server (LSP):**
  * Port `6005` aktif mendengarkan (`LISTEN`) pada IP `127.0.0.1`.
  * Koneksi TCP diverifikasi dengan `nc -zv 127.0.0.1 6005` (Status: *Succeeded*).
* **External Editor Handshake:**
  * File `editor_settings-4.7.tres` telah mengaktifkan `use_external_editor=true`.
  * Path eksekusi mengarah ke binary valid: `/Users/restuwibisono/.antigravity-ide/antigravity-ide/bin/antigravity-ide`.
  * Parameter eksekusi: `{project} --goto {file}:{line}:{col}`.
* **Evaluasi Error Riwayat:**
  * Pesan error riwayat `Ran list project petualang-untidar · Exited with code 1` telah dipastikan terjadi akibat eksekusi perintah shell yang salah sintaks pada sesi sebelumnya, bukan kerusakan pada file proyek atau engine Godot.

---

## 7. Testing & Validation

| Pengujian | Metode Uji | Hasil Aktual | Status |
| :--- | :--- | :--- | :---: |
| Ketersediaan CLI `godot` | `which godot` & `ls -l ~/.local/bin/godot` | Mengarah ke `/Applications/Godot.app/Contents/MacOS/Godot` | PASS |
| Status Proses Godot Engine | `ps aux \| grep -i godot` | Godot 4.7 aktif membuka project `petualang-untidar` | PASS |
| Port LSP 6005 | `nc -zv 127.0.0.1 6005` | Connection Succeeded | PASS |
| Struktur File Inti | `ls -la` di root project | `project.godot`, `icon.svg`, `scripts/main.gd` terkonfirmasi ada | PASS |
| Integritas Git | `git status` | Not a git repo (Perlu git init) | WARNING |

---

## 8. Known Issues & Risks

1. **Belum Ada Version Control (Git):** Proyek belum terhubung ke Git. Risiko kehilangan kode dan histori perubahan sangat tinggi jika tidak segera diinisialisasi.
2. **Potensi Pixel Art Blurring:** Belum disetelnya `default_texture_filter` ke `Nearest` akan menyebabkan gambar kabur begitu sprite pertama diimpor.
3. **Ketiadaan Input Map:** Karakter atau controller tidak akan merespons tombol apa pun tanpa pendaftaran action di `project.godot`.
4. **Struktur Direktori Belum Terstandarisasi:** Belum ada folder modular untuk entities, components, resources, audio, dan visual.

---

## 9. Remaining Tasks & Next Steps

* [ ] Inisialisasi Git repository lokal dan siapkan `.gitignore` khusus Godot 4.
* [ ] Terapkan konfigurasi pixel-perfect, input map, dan display settings pada `project.godot`.
* [ ] Bangun struktur direktori proyek sesuai rancangan arsitektur teknis.
* [ ] Siapkan fondasi core components dan Autoload (Phase 1 Implementation).

