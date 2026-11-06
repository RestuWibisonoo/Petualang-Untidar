# Character Asset Standard: Petualang Untidar

- **Dokumen:** Standar Teknis & Pedoman Produksi Aset Pixel Art Karakter
- **Target Resolusi Viewport:** 640 × 360 (Rasio 16:9, Integer Scale ke 720p/1080p/4K)
- **Status:** APPROVED STANDARD
- **Tanggal:** 2026-11-06

---

## 1. Spesifikasi Resolusi Kanvas & Proporsi

### 1.1 Ukuran Kanvas Per Frame
* **Ukuran Kanvas Standar:** **`32 × 32` piksel per frame**.
* **Tinggi Efektif Karakter:** 24 – 28 piksel (proporsi *chibi semi-realistic* 1:2.5 kepala ke badan).
* **Justifikasi terhadap Viewport 640×360:**
  * Pada viewport vertikal 360 piksel, karakter setinggi ~26 piksel menempati sekitar **7.2% tinggi layar**, setara dengan 11–13 tile grid per layar vertikal (seperti *The Legend of Zelda: The Minish Cap* dan *Chrono Trigger*).
  * Memberikan jarak pandang eksplorasi (*field of view*) yang cukup luas untuk membaca posisi musuh, teka-teki, dan tata letak kampus Untidar tanpa membuat karakter tampak terlalu kecil di layar smartphone.

---

## 2. Pivot Point & Alignment

* **Posisi Poros (Pivot Point):** **Bottom-Center (Pusat Bawah)**.
* **Titik Koordinat Poros:** `(X: 16, Y: 28)` pada kanvas 32×32.
* **Tujuan Alignment:**
  1. Kaki karakter menapak tepat pada titik koordinat `(0, 0)` lokal node Godot.
  2. Memastikan collision kapsul `CollisionShape2D` di kaki `(0, 8)` selalu akurat.
  3. Memastikan pengurutan kedalaman visual (**Y-Sort**) berjalan presisi saat karakter melintas di depan atau di belakang pohon/bangunan.
  4. Seluruh layer modular (rambut, pakaian, zirah, senjata) digambar dengan pivot yang identik agar tidak terjadi pergeseran (*drift*) antar layer.

---

## 3. Urutan Penumpukan Layer (Z-Order)

Karakter menggunakan arsitektur penumpukan 10 layer `Sprite2D` di dalam node `ModularVisuals`:

| Urutan (Bawah ke Atas) | Nama Layer Node | Z-Index Relatif | Deskripsi / Isi Layer |
| :---: | :--- | :---: | :--- |
| **1** | `AccessoryBack` | -1 | Ransel, tas selempang, jubah punggung, tabung panah. |
| **2** | `Body` | 0 | Kulit dasar karakter, anatomi tubuh, mata, dan ekspresi wajah. |
| **3** | `Legwear` | 1 | Celana panjang, celana pendek, rok, sepatu/sepatu bot. |
| **4** | `Clothing` | 2 | Kemeja, kaos almamater, seragam dasar dalam. |
| **5** | `Armor` | 3 | Rompi pelindung, jas lab, zirah dada, jaket almamater tebal. |
| **6** | `Headgear` | 4 | Topi toga, helm proyek, pita rambut, kupluk, bandana. |
| **7** | `Hair` | 5 | Rambut depan/belakang, poni, gaya rambut karakter. |
| **8** | `AccessoryFront` | 6 | Kacamata, kalung id card, masker, syal leher. |
| **9** | `Weapon` | 7 | Senjata tangan utama (pena sakti, tongkat komando, pedang, penggaris T). |
| **10** | `Effects` | 8 | Partikel aura, kilatan sabetan senjata, debu roll/dash. |

---

## 4. Layout Spritesheet & Struktur Grid

Setiap berkas tekstur modular wajib diexport dalam format grid persegi berulang yang identik:

* **Grid Dimensi:** 4 Kolom × 4 Baris = 16 Frame.
* **Total Ukuran Berkas PNG:** `128 × 128` piksel.
* **Pembagian Baris (Arah Hadap):**
  * **Baris 0 (Y: 0–31):** Hadap Bawah (*Down / South*) — Frame 0, 1, 2, 3.
  * **Baris 1 (Y: 32–63):** Hadap Atas (*Up / North*) — Frame 4, 5, 6, 7.
  * **Baris 2 (Y: 64–95):** Hadap Kanan (*Right / East*) — Frame 8, 9, 10, 11.
  * **Baris 3 (Y: 96–127):** Hadap Kiri (*Left / West*) — Frame 12, 13, 14, 15.

```
       Col 0        Col 1        Col 2        Col 3
     ┌────────────┬────────────┬────────────┬────────────┐
Row 0│ Down_0     │ Down_1     │ Down_2     │ Down_3     │ (Down / South)
     ├────────────┼────────────┼────────────┼────────────┤
Row 1│ Up_0       │ Up_1       │ Up_2       │ Up_3       │ (Up / North)
     ├────────────┼────────────┼────────────┼────────────┤
Row 2│ Right_0    │ Right_1    │ Right_2    │ Right_3    │ (Right / East)
     ├────────────┼────────────┼────────────┼────────────┤
Row 3│ Left_0     │ Left_1     │ Left_2     │ Left_3     │ (Left / West)
     └────────────┴────────────┴────────────┴────────────┘
```

---

## 5. Konvensi Penamaan Animasi & Arah

Format nama animasi di `AnimationPlayer`: `<action>_<direction>`

* **Animasi Inti:**
  * `idle_down`, `idle_up`, `idle_left`, `idle_right` (Durasi: 0.1–0.4s, Looping).
  * `walk_down`, `walk_up`, `walk_left`, `walk_right` (Durasi: 0.4s, 4 frame step, Looping).
  * `roll_down`, `roll_up`, `roll_left`, `roll_right` (Durasi: 0.25s, One-shot).
* **Pemetaan Arah Diagonal:**
  * Gerakan input 8-arah (`down_right`, `down_left`, `up_right`, `up_left`) secara otomatis dipetakan ke 4 animasi arah utama berdasarkan sumbu dominan dan memori arah hadap terakhir pemain.

---

## 6. Standar Teknis & Import di Godot 4.7

1. **Format Berkas:** PNG 32-bit (RGBA8).
2. **Transparansi:** Latar belakang harus 100% transparan (`#00000000`). Tidak boleh ada pixel halo/fringe putih.
3. **Konfigurasi Import Godot (`.import`):**
   * `textures/canvas_textures/default_texture_filter`: **`0 (Nearest)`** (Wajib agar pixel tidak buram).
   * `compress/mode`: **`Lossless`** (Menjaga ketajaman warna pixel art tanpa kompresi artefak).
   * `mipmaps/generate`: **`false`** (Dinonaktifkan untuk grafis 2D murni).

