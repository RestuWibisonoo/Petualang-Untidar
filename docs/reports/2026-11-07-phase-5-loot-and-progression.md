# Implementation Report: Phase 5 — Loot & Progression

- **Tanggal Pelaksanaan:** 2026-11-08 (Updated Final Blocker Fixes)
- **Status:** COMPLETED & REGRESSION VERIFIED (100% PASS)
- **Pelaksana:** Senior Godot Game Developer & Game Systems Architect
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Renderer:** GL Compatibility
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan sistem **Loot, Inventory, Equipment, dan Character Progression** pada **Phase 5** untuk game *Petualang Untidar* berdasarkan arsitektur Phase 1 sampai Phase 4 yang telah disetujui:
1. **Item & Equipment Custom Resources:** Perancangan model data terstruktur `ItemData` dan `EquipmentData` berbasis Godot Custom Resource (`.tres`), dilengkapi 6 aset sampel konkret (Wooden Sword, Iron Sword, Cloth Armor, Leather Armor, Health Potion, Slime Jelly) berserta ikon pixel art 16x16.
2. **Inventory System (20 Slot) & Mutation Invariants:** Pengelolaan inventaris `InventoryManager` dengan model slot `InventorySlot` (`RefCounted`), fungsi validasi terpusat `validate_item_state()`, penggabungan stack otomatis (*stack merging*), distribusi luapan (*stack overflow*), penambahan parsial (*partial insertion*), pemindahan dan penukaran slot atomik (*atomic swap/move*), dan perlindungan mutasi eksternal via deep-copy snapshot.
3. **Equipment System & Modular Visuals:** Manajemen perlengkapan `EquipmentManager` dengan 4 slot terdedikasi (`weapon`, `head`, `body`, `accessory`), penukaran langsung di tempat (*in-place inventory swap*), perlindungan pelepasan saat inventaris penuh (*zero item loss*), pembersihan layer visual sprite saat unequip dan sinkronisasi ulang (`ModularVisuals.set_layer_texture(layer, null)`), dan pemicuan rekalkulasi stat tempur hanya setelah transaksi berhasil.
4. **Character Stats & Level Progression:** Penghitungan status karakter `CharacterStats` menggabungkan Base Stats, Equipment Bonuses, dan Allocated Progression Points. Otoritas runtime HP tempur berada di `HealthComponent`, disinkronkan secara konsisten ke `CharacterStats` tanpa rekursif. Dilengkapi mekanisme kurva level EXP progresif $\text{int}(100 \times \text{level}^{1.4})$, akumulasi luapan multi-level (*multi-level overflow*), alokasi stat point (+3/level), serta pencegahan eksploitasi darah penuh (*max HP clamping anti auto-heal*).
5. **Combat System Integration:** Menghubungkan Attack langsung ke damage kombo 2-tahap `PlayerAttackState`, Defense ke reduksi kerusakan di `HurtboxComponent`, dan Move Speed ke `VelocityComponent`.
6. **Loot Drop & Ground Item System:** Pemodelan `LootTable` dan `LootDropEntry` yang mendukung evaluasi peluang independen ($< \text{drop\_chance}$, peluang 0.0 tidak pernah drop, 1.0 selalu drop) dan distribusi kolam berbobot (*weighted pool*) dengan validasi invariant `is_valid()` dan injeksi RNG deterministik. Entitas fisik tanah `WorldItem` (`Area2D` di Layer 8) dengan animasi floating/bobbing sinusoidal, single-pickup lock, dan penolakan aman di tanah jika inventaris penuh (*ground rejection*). Serta `LootSpawner` yang merespons `EventBus.enemy_defeated_at` untuk mendistribusikan EXP dan memunculkan loot secara aman via `call_deferred`.
7. **User Interface (InventoryUI) & Mobile Controls:** Antarmuka responsif 640x360 dengan grid 20 slot, panel detail item, tombol aksi (Pasang/Gunakan/Buang), visual 4 slot perlengkapan, sinkronisasi penggunaan Health Potion ke `HealthComponent` dan `CharacterStats`, bilah progres EXP, panel atribut tempur, alokasi stat points (+), pintasan tombol keyboard ('I', 'C', Esc), dan penambahan tombol aksi `%InventoryButton` pada `TouchControls`.
8. **Automated Unit & Runtime Verification:**
   - `tests/test_phase_5.gd`: 182 assertions unit validation (100% PASS).
   - `tests/runtime_validation_phase_5.gd`: 58 assertions runtime physics simulation (100% PASS).
   - Regresi total proyek: 671 / 671 assertions lulus pada 8 test suites (100% PASS).

---

## 2. Item & Equipment Data Architecture

### 2.1 Model Data Custom Resource
Data item didefinisikan menggunakan hierarki Custom Resource (`.tres`) bertipe ketat:

- **`ItemData` (`scripts/resources/item_data.gd`):**
  - `item_id: StringName` (Identitas unik item).
  - `item_name: String` (Nama tampilan item).
  - `description: String` (Deskripsi fungsi dan cerita item).
  - `icon: Texture2D` (Ikon pixel art item).
  - `item_type: ItemType` (`CONSUMABLE`, `EQUIPMENT`, `MATERIAL`, `QUEST`).
  - `rarity: Rarity` (`COMMON`, `UNCOMMON`, `RARE`, `EPIC`, `LEGENDARY`).
  - `max_stack: int` (Batas maksimum tumpukan per slot, 1 untuk equipment).
  - `sell_value: int` (Nilai jual item dalam koin).
  - Helper: `is_stackable() -> bool` (mengembalikan `max_stack > 1`).

- **`EquipmentData` (`scripts/resources/equipment_data.gd` - mewarisi `ItemData`):**
  - `equipment_slot: EquipmentSlot` (`WEAPON`, `HEAD`, `BODY`, `ACCESSORY`).
  - `attack_bonus: int` (Tambahan stat serangan).
  - `defense_bonus: int` (Tambahan stat pertahanan).
  - `health_bonus: int` (Tambahan kapasitas HP maksimal).
  - `movement_speed_bonus: float` (Tambahan kecepatan gerak).
  - `visual_layer: StringName` (Target layer pada `ModularVisuals`).

### 2.2 Katalog Sampel Item Konkret
Tersimpan di direktori `resources/equipment/` dan `resources/items/`:

| Nama Item | Berkas Resource | Tipe | Slot | Stat Bonus | Max Stack | Rarity |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Wooden Sword** | `wooden_sword.tres` | Equipment | Weapon | +5 ATK | 1 | Common |
| **Iron Sword** | `iron_sword.tres` | Equipment | Weapon | +12 ATK | 1 | Uncommon |
| **Cloth Armor** | `cloth_armor.tres` | Equipment | Body | +2 DEF, +10 HP | 1 | Common |
| **Leather Armor** | `leather_armor.tres` | Equipment | Body | +5 DEF, +25 HP | 1 | Uncommon |
| **Health Potion** | `health_potion.tres` | Consumable | - | Memulihkan 30 HP | 20 | Common |
| **Slime Jelly** | `slime_jelly.tres` | Material | - | Bahan mentah monster | 99 | Common |

---

## 3. Inventory Architecture

### 3.1 Model Slot & Transaksi Atomik
- **`InventorySlot` (`scripts/systems/inventory_slot.gd`):** Berbasis `RefCounted` ringan untuk menghindari overhead node scene. Menyimpan `item: ItemData` dan `quantity: int`.
- **`InventoryManager` (`scripts/systems/inventory_manager.gd`):** Komponen dengan kapasitas tetap 20 slot:
  - **Stack Merging & Overflow:** Logika `add_item()` memindai slot yang sudah berisi item identik untuk menambah kuantitas hingga `item.max_stack`. Sisa kuantitas otomatis meluap ke slot kosong berikutnya.
  - **Partial Insertion:** Jika ruang inventaris tidak mencukupi untuk menampung seluruh kuantitas item baru, sistem memasukkan kuantitas yang muat dan mengembalikan sisa yang tertolak (menghindari kegagalan total atau kehilangan item).
  - **Atomic Move & Swap:** Fungsi `swap_slots(from_index, to_index)` menukar isi dua slot secara atomik dalam 1 operasi frame. Jika kedua slot berisi item stackable yang sama, sistem melakukan penggabungan stack otomatis.
  - **Snapshot & Reading Integrity:** `get_inventory_snapshot()` dan `get_slot_data()` menduplikasi resource `ItemData` (`duplicate(true)`) dan mengisolasi struktur pembacaan, menjamin pihak luar tidak dapat memodifikasi inventory maupun resource asli.
  - **Official Mutation API:** Seluruh manipulasi slot dilakukan melalui API resmi `replace_slot_item()`, `set_slot()`, dan `clear_slot()`.

---

## 4. Equipment System & Modular Visuals Integration

### 4.1 Logika EquipmentManager (`scripts/systems/equipment_manager.gd`)
- Memiliki 4 slot terdedikasi: `"weapon"`, `"head"`, `"body"`, `"accessory"`.
- **Pemasangan Atomik (`equip_item_from_inventory`):**
  1. Menggunakan API resmi `InventoryManager.replace_slot_item()`.
  2. Jika slot equipment sudah terisi, item yang sedang terpasang ditukar langsung (*swapped in-place*) ke slot inventaris asal.
- **Pelepasan Aman (`unequip_item`):**
  - Memeriksa ruang kosong di `InventoryManager`. Jika inventaris 100% penuh, proses pelepasan ditolak secara aman (`return false`) tanpa risiko item hilang (*zero item loss*).
- **Sinkronisasi Visual & Combat:**
  - Memanggil `ModularVisuals.set_layer_texture(layer_name, texture)` untuk mengubah tampilan sprite pemain secara instan.
  - Memanggil `stats.recalculate()` untuk memperbarui total atribut karakter.

---

## 5. Character Progression & Combat Integration

### 5.1 Komposisi Status (`CharacterStats`)
Formula komprehensif penghitungan statistik:
$$\text{Attack} = \text{base\_attack} + \text{equipment\_attack} + \text{allocated\_attack}$$
$$\text{Defense} = \text{base\_defense} + \text{equipment\_defense} + \text{allocated\_defense}$$
$$\text{Max HP} = \text{base\_max\_health} + \text{equipment\_health} + \text{allocated\_health}$$
$$\text{Move Speed} = \text{base\_move\_speed} + \text{equipment\_speed}$$

### 5.2 Aturan Anti-Exploit Max HP Clamping
- Saat melepas zirah berbonus HP, jika `current_health > max_health_baru`, maka `current_health` dipangkas (*clamped*) tepat di batas maksimum baru.
- Saat memasang zirah berbonus HP, `current_health` **tidak bertambah instan** (*no auto-heal exploit*).

### 5.3 Level Progression & Overflow Handling
- **Formula EXP Kebutuhan:**
  $$\text{Required EXP}(level) = \text{int}(100 \times level^{1.4})$$
  - Level 1: 100 EXP
  - Level 2: 263 EXP
  - Level 3: 465 EXP
- **Multi-Level Overflow:** Jika pemain mendapatkan EXP dalam jumlah besar dari boss atau quest, sistem menjalankan perulangan `while current_exp >= exp_to_next_level` sehingga pemain dapat naik level beberapa kali secara berurutan dalam 1 event tanpa kehilangan kelebihan EXP.
- **Stat Points:** Setiap kenaikan level memberikan 3 Stat Point bebas. Pemain dapat mengalokasikannya melalui UI ke:
  - +10 Max Health
  - +2 Attack
  - +1 Defense

### 5.4 Integrasi Dinamis ke Combat Phase 4
- **`PlayerAttackState`:** Damage kombo Stage 1 dan Stage 2 diskalakan dari selisih `character_stats.attack - character_stats.base_attack` tanpa hardcoded value 15.
- **`HurtboxComponent`:** Menyerap raw damage musuh berdasarkan total defense karakter.
- **`VelocityComponent`:** Menyesuaikan kecepatan lari dasar berdasarkan total kecepatan pada `CharacterStats`.

---

## 6. Loot Drop & Ground Item System

### 6.1 Desain LootTable (`LootTable` & `LootDropEntry`)
- Mendukung dua mode evaluasi:
  1. **Independent Chance:** Setiap entitas item dalam tabel memiliki persentase jatuh masing-masing ($0.0 - 1.0$).
  2. **Weighted Random Pool:** Memilih satu item dari kumpulan entitas berdasarkan bobot probabilitas relatif.
- Memiliki injeksi RNG (`rng: RandomNumberGenerator`) sehingga pengujian unit dan simulasi runtime dapat dijalankan secara deterministik (100% reproducible).

### 6.2 Entitas Dunia `WorldItem` (`scenes/objects/world_item.tscn`)
- Turunan `Area2D` pada **Collision Layer 8 (Interactables)**.
- Menampilkan sprite item 16x16 dengan efek melayang sinusoidal (*floating bobbing animation*):
  $$y(t) = y_0 + \sin(t \times 4.5) \times 2.0$$
- **Auto-Pickup, Interaction & Partial Pickup:** Pemain dapat mengambil item cukup dengan menyentuh area item (`_on_body_entered`) atau menekan tombol interaksi (`interact`). Jika inventaris hanya mampu menampung sebagian kuantitas, item berkurang dan sisanya tetap berada di tanah. Entitas hanya di-free jika `quantity <= 0`.
- **Single-Pickup Lock:** Dilengkapi variabel boolean `_is_processing_pickup` untuk mencegah pemanggilan berulang pada frame yang sama.
- **Ground Rejection Safety:** Jika inventaris pemain penuh, item tidak dipungut, tetap berada di lantai dengan aman, dan memancarkan teks melayang "*Tas Penuh!*".

### 6.3 Decoupled `LootSpawner`
- Ditempatkan di dalam scene dunia (`WorldBase`), mendengarkan `EventBus.enemy_defeated_at(enemy_id, position, exp_reward, loot_table, enemy_instance_id)`.
- Menggunakan `enemy_instance_id` untuk deduplikasi (setiap musuh unik hanya memberikan reward satu kali; dua musuh ber-`enemy_id` sama yang mati hampir bersamaan tetap memberikan reward masing-masing secara independen). Cache dibersihkan berkala untuk mencegah memory leak.
- Memberikan hadiah EXP langsung ke `CharacterStats` pemain secara data-driven tanpa fallback default hardcoded.
- Mengevaluasi tabel loot musuh dan menambahkan instans `WorldItem` ke dunia secara tertunda via `call_deferred("add_child", world_item)`, sepenuhnya mengeliminasi error `Can't change this state while flushing queries` dari physics engine Godot.

---

## 7. User Interface (InventoryUI) & Controls

### 7.1 Antarmuka Responsif (640x360 Pixel Art)
- Node `InventoryUI` (`scenes/ui/inventory_ui.tscn`) berada pada CanvasLayer 5:
  - **Grid Panel 20 Slot:** Grid layout 5 kolom x 4 baris, dilengkapi indikator kursor seleksi slot aktif.
  - **Equipment Slots:** Preview visual untuk slot Head, Weapon, Body, Pants, Accessory.
  - **Stat & Progression Display:** Menampilkan Level karakter, Bilah ProgressBar EXP, Total HP, Total Attack, Total Defense, dan Movement Speed.
  - **Stat Allocation Control:** Tombol `+` aktif hanya jika pemain memiliki sisa Stat Points.
  - **Detail & Action Panel:** Menampilkan ikon besar, nama, deskripsi, dan tombol aksi dinamis (`Equip` / `Unequip` / `Drop`).

### 7.2 Kontrol Keyboard & Layar Sentuh Mobile
- **Keyboard Shortcuts:**
  - `I` atau `C`: Buka / Tutup panel inventaris.
  - `Escape`: Tutup inventaris jika sedang terbuka.
- **Mobile Touch Controls:**
  - Menambahkan `%InventoryButton` pada `TouchControls` (`scenes/ui/touch_controls.tscn`).
  - Menekan tombol ransel di layar ponsel mensintesis action event `inventory` secara mulus tanpa interferensi ke tombol virtual joystick.

---

## 8. Verification & Test Results

### 8.1 Phase 5 Automated Unit Test Suite (`tests/test_phase_5.gd`)
Dijalankan secara headless menggunakan engine Godot 4.7.2:
```bash
godot --headless -s tests/test_phase_5.gd
```
**Hasil:** **182 / 182 assertions PASS (100%)**
- *Section 1: ItemData & EquipmentData Resources* (20 assertions) - PASS
- *Section 2: Inventory Stacking, Capacity & Partial Insertion* (21 assertions) - PASS
- *Section 3: Inventory Move, Swap, Snapshot Safety & Invariant Mutation* (34 assertions) - PASS
- *Section 4: EquipmentManager Atomic Equip, Unequip, Visual Cleanup & Resync* (22 assertions) - PASS
- *Section 5: CharacterStats Calculation & Dynamic Combat Scaling* (23 assertions) - PASS
- *Section 6: EXP Curve, Multi-Level Overflow & Stat Points* (17 assertions) - PASS
- *Section 7: LootTable, Probability Invariants & Deterministic Rolls* (24 assertions) - PASS
- *Section 8: WorldItem Pickup Logic & Full Inventory Ground Rejection* (21 assertions) - PASS

### 8.2 Phase 5 Runtime Physics Simulation (`tests/runtime_validation_phase_5.gd`)
Menguji integrasi gameplay aktif multi-frame di arena tempur:
```bash
godot --headless -s tests/runtime_validation_phase_5.gd
```
**Hasil:** **58 / 58 assertions PASS (100%)**
- *Simulation 1: Arena World Item Spawning & Enemy Defeat* (6 assertions) - PASS
- *Simulation 2: WorldItem Auto-Pickup and Inventory Insertion* (2 assertions) - PASS
- *Simulation 3: Equipment Dynamic Combat Scaling & Enemy Impact* (5 assertions) - PASS
  - Baseline attack: 13 damage (15 ATK - 2 Slime DEF).
  - Iron Sword equipped: 25 damage (27 ATK - 2 Slime DEF, +12 damage scaling).
- *Simulation 4: Enemy Defeat EXP Reward, Level Up & Stat Points* (7 assertions) - PASS
- *Simulation 5: Full Inventory Ground Rejection* (4 assertions) - PASS
- *Simulation 6: Runtime Partial Pickup & Remainder Collection* (6 assertions) - PASS
- *Simulation 7: Runtime Dual Enemy Defeat with Same Enemy ID* (3 assertions) - PASS
- *Simulation 8: Inventory UI Toggle & Display Synchronization* (7 assertions) - PASS
- *Simulation 9: Health Potion Synchronization & HP Invariants* (18 assertions) - PASS
  - HP start 100/100, damage ke 60, potion menyembuhkan ke 90, 1 potion berkurang.
  - Potion saat 90 HP tidak melebihi 100 Max HP (clamped).
  - Potion saat 100 HP tidak mengubah HP.
  - Equip item penambah Max HP tidak menghasilkan auto-heal.
  - Hurt state, knockback, dan i-frames tetap berfungsi normal.

### 8.3 Full Project Regression Summary Across All Phases

| Suite Pengujian | File Pengujian | Jumlah Assertions | Hasil |
| :--- | :--- | :---: | :---: |
| **Phase 1 Unit Suite** | `tests/test_phase_1.gd` | 45 | **45 / 45 PASS** |
| **Phase 2 Unit Suite** | `tests/test_phase_2.gd` | 73 | **73 / 73 PASS** |
| **Phase 3 Unit Suite** | `tests/test_phase_3.gd` | 91 | **91 / 91 PASS** |
| **Phase 3 Runtime Suite** | `tests/runtime_validation_phase_3.gd` | 78 | **78 / 78 PASS** |
| **Phase 4 Unit Suite** | `tests/test_phase_4.gd` | 97 | **97 / 97 PASS** |
| **Phase 4 Runtime Suite** | `tests/runtime_validation_phase_4.gd` | 47 | **47 / 47 PASS** |
| **Phase 5 Unit Suite** | `tests/test_phase_5.gd` | 182 | **182 / 182 PASS** |
| **Phase 5 Runtime Suite** | `tests/runtime_validation_phase_5.gd` | 58 | **58 / 58 PASS** |
| **TOTAL KESELURUHAN** | **8 Test Suites** | **671** | **671 / 671 PASS (100%)** |

---

## 9. Summary of Created & Modified Files

### 9.1 Berkas Baru (New Files)
- `scripts/resources/item_data.gd`
- `scripts/resources/equipment_data.gd`
- `scripts/resources/loot_drop_entry.gd`
- `scripts/resources/loot_table.gd`
- `scripts/systems/inventory_slot.gd`
- `scripts/systems/inventory_manager.gd`
- `scripts/systems/equipment_manager.gd`
- `scripts/systems/character_stats.gd`
- `scripts/systems/loot_spawner.gd`
- `scripts/objects/world_item.gd`
- `scenes/objects/world_item.tscn`
- `scripts/ui/inventory_ui.gd`
- `scenes/ui/inventory_ui.tscn`
- `resources/equipment/wooden_sword.tres`
- `resources/equipment/iron_sword.tres`
- `resources/equipment/cloth_armor.tres`
- `resources/equipment/leather_armor.tres`
- `resources/items/health_potion.tres`
- `resources/items/slime_jelly.tres`
- `resources/enemies/dummy_slime_loot.tres`
- `assets/items/wooden_sword.png` (+ `.import`)
- `assets/items/iron_sword.png` (+ `.import`)
- `assets/items/cloth_armor.png` (+ `.import`)
- `assets/items/leather_armor.png` (+ `.import`)
- `assets/items/health_potion.png` (+ `.import`)
- `assets/items/slime_jelly.png` (+ `.import`)
- `tests/test_phase_5.gd`
- `tests/runtime_validation_phase_5.gd`
- `docs/reports/2026-11-07-phase-5-loot-and-progression.md`

### 9.2 Berkas yang Dimodifikasi (Modified Files)
- `scripts/autoload/event_bus.gd` (Menambahkan sinyal `player_leveled_up`, `exp_gained`, `enemy_defeated_at`).
- `scripts/enemy/base_enemy.gd` (Mendukung `exp_reward`, `loot_table`, dan pemancaran `enemy_defeated_at`).
- `scripts/player/player.gd` & `scenes/player/player.tscn` (Instansiasi dan penghubungan `InventoryManager`, `EquipmentManager`, `CharacterStats`).
- `scripts/player/states/player_attack_state.gd` (Skalasi damage combo dinamis dari `character_stats.attack`).
- `scripts/world/world_base.gd` (Instansiasi otomatis `LootSpawner` dan `InventoryUI` pada HUD level).
- `scripts/ui/touch/touch_controls.gd` & `scenes/ui/touch_controls.tscn` (Menambahkan tombol sentuh `%InventoryButton`).
- `docs/development/roadmap.md` (Pembaruan status Phase 4 dan Phase 5 ke COMPLETED).
- `docs/architecture/technical-architecture.md` (Dokumentasi arsitektur Loot, Inventory, Equipment, Progression).
- `docs/decisions/technical-decisions.md` (Pencatatan ADR-019 hingga ADR-022).

---

## 10. Technical Debt & Next Steps

1. **Modular Visuals Weapon & Armor Directional Frames:** `ModularVisuals` saat ini menggunakan fallback terisolasi (`attack_down` dan `idle_down`) saat aset frame arah samping/atas untuk pedang dan zirah belum di-render oleh tim art. Aset grafis lengkap akan dihubungkan pada iterasi polish visual.
2. **Mobile Hardware Touch Stress Testing:** Diperlukan pengujian perangkat keras Android nyata untuk menguji kenyamanan ukuran tap target tombol `%InventoryButton` dan slot grid inventaris (direncanakan pada Phase 8: Polish & Platform Optimization).
3. **Persiapan Phase 6 (Dungeon & Puzzles):** Fondasi inventory, combat, level, dan loot telah siap 100% untuk digunakan pada puzzle lingkungan, pintu terkunci berbatu kunci (*dungeon keys*), dan pertarungan boss bertingkat.

