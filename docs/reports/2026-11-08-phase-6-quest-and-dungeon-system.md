# Implementation Report: Phase 6 — Quest & Dungeon System

- **Tanggal Pelaksanaan:** 2026-11-08
- **Status:** COMPLETED & REGRESSION VERIFIED (100% PASS)
- **Pelaksana:** Senior Godot Game Developer & Game Systems Architect
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Renderer:** GL Compatibility
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan sistem **Quest, Dialogue, Dungeon Key, dan Boss Encounter** pada **Phase 6** untuk game *Petualang Untidar* berbasis arsitektur terpadu Phase 1 sampai Phase 5:
1. **Data-Driven Quest & Objectives Architecture:** Perancangan model data Custom Resource `QuestData` dan `QuestObjectiveData` (`.tres`), mendukung 3 tipe objektif (`KILL_ENEMY`, `COLLECT_ITEM`, `TALK_TO_NPC`), alur prasyarat quest (*prerequisite chaining*), reward EXP dan item, serta fungsi validasi invarian `is_valid()`.
2. **Decoupled Runtime Quest Progress:** Pemodelan `QuestRuntimeState` yang memisahkan status runtime (`NOT_STARTED`, `ACTIVE`, `COMPLETED`, `REWARD_CLAIMED`) dan pencatatan progres per-objektif dari berkas `.tres` statis, dilengkapi clamping nilai aman `[0, required_amount]` dan serialisasi save/load dictionary (`to_dict()`, `from_dict()`).
3. **Event-Driven Quest Manager & Deduplication:** Komponen `QuestManager` terpusat yang mendengarkan event global `enemy_defeated_at`, `item_collected`, dan `npc_interacted`. Dilengkapi cache deduplikasi terbatas (*bounded deduplication cache*) berbasis `enemy_instance_id` untuk mencegah lonjakan duplikasi hitungan kill, kemampuan memajukan multi-quest dari satu event, dan transaksi klaim hadiah atomik (*atomic reward claim*) yang memvalidasi kapasitas inventaris multi-slot sebelum mutasi.
4. **NPC & Dialogue System:** Resource `DialogueData` dan canvas layer `DialogueUI` (Layer 25) dengan navigasi percakapan multiline, dukungan keyboard dan layar sentuh, penguncian kendali pemain (*player input lock* `is_input_locked = true`), serta entitas `NPC` dengan `Interactable` (Layer 8: 128) yang menyajikan dialog stateful adaptif (default/active/completed).
5. **Dungeon Key & Dungeon Door Mechanics:** Item resource `dungeon_key.tres` dan komponen `DungeonDoor` yang memverifikasi ketersediaan kunci melalui `InventoryManager`, mengonsumsi kunci secara aman, mencegah race condition saat transisi scene, dan menghubungkan overworld ke ruangan boss dungeon.
6. **Two-Phase Boss Encounter:** Entitas `BossEnemy` turunan `BaseEnemy` (`boss_gorgon`, 200 HP, 20 Base Damage, 4 DEF, 500 EXP). Memiliki mekanisme Enrage otomatis ke Fase 2 saat HP $\le 50\%$ (kecepatan 75 px/s, damage 30, cooldown 0.7s, aura merah), memancarkan sinyal `enraged` dan `phase_changed(2)`, single death reward tanpa duplikasi, dan drop loot table khusus `boss_gorgon_loot.tres`.
7. **Quest UI & Mobile Controls:** Antarmuka `QuestUI` pada CanvasLayer 24 dengan pemisahan tab Quest Aktif & Selesai, checklist dinamis objektif (`[✓]`), preview hadiah EXP dan item, tombol interaktif "Klaim Hadiah", toast notification bar, shortcut keyboard 'Q' (`quest_log`), serta tombol aksi mobile `%QuestButton` pada `TouchControls`.
8. **Automated Testing & Full Project Regression:**
   - `tests/test_phase_6.gd`: 93 assertions unit validation (100% PASS).
   - `tests/runtime_validation_phase_6.gd`: 44 assertions runtime multi-frame simulation (100% PASS).
   - Regresi total proyek: 708 / 708 assertions lulus di seluruh 10 test suite (Phase 1–6) tanpa galat (100% PASS).

---

## 2. Quest Data & Runtime State Architecture

### 2.1 Model Data Blueprint Statis
Data quest dirancang berbasis Custom Resource Godot (`.tres`) untuk menjamin sifat data-driven:
- **`QuestObjectiveData` (`scripts/resources/quest_objective_data.gd`):**
  - `ObjectiveType`: Enum `KILL_ENEMY = 0`, `COLLECT_ITEM = 1`, `TALK_TO_NPC = 2`.
  - `objective_id: StringName`: Identitas unik tugas dalam quest (misal `&"kill_slimes"`).
  - `target_id: StringName`: ID target yang dipantau (misal `&"dummy_slime"`, `&"slime_jelly"`, `&"npc_guide"`).
  - `required_amount: int`: Jumlah target yang harus dicapai.
  - `description: String`: Teks instruksi untuk ditampilkan pada UI.
  - `is_valid() -> bool`: Memeriksa bahwa ID tidak kosong dan required_amount > 0.
- **`QuestData` (`scripts/resources/quest_data.gd`):**
  - `quest_id: StringName`: Identitas unik quest.
  - `title: String` & `description: String`: Judul dan narasi quest.
  - `quest_giver_id: StringName`: ID NPC pemberi quest.
  - `objectives: Array[QuestObjectiveData]`: Daftar objektif yang harus dipenuhi.
  - `reward_exp: int`: Jumlah reward EXP karakter saat klaim.
  - `reward_items: Array[Dictionary]`: Daftar item hadiah (`item: ItemData`, `quantity: int`).
  - `prerequisite_quest_ids: Array[StringName]`: Daftar ID quest prasyarat yang harus diselesaikan sebelum quest ini dapat diambil.
  - `is_valid() -> bool`: Memvalidasi kelengkapan quest dan seluruh objektifnya.

### 2.2 Decoupled Runtime Progress (`QuestRuntimeState`)
Untuk mencegah mutasi pada file `.tres` saat runtime, progres quest dipisahkan ke dalam kelas `QuestRuntimeState` (`RefCounted`):
- `status`: Enum `NOT_STARTED`, `ACTIVE`, `COMPLETED`, `REWARD_CLAIMED`.
- `objective_progress: Dictionary`: Menyimpan progres pencapaian tiap objektif (`objective_id -> int`).
- `add_progress(objective_id, delta, required_amount) -> int`: Menambahkan progres secara otomatis dengan clamping `[0, required_amount]`.
- `are_all_objectives_completed(quest_data) -> bool`: Memeriksa apakah seluruh objektif telah mencapai batas minimum.
- `to_dict() -> Dictionary` & `from_dict(data) -> QuestRuntimeState`: Ekspor dan impor data dictionary untuk penyimpanan save game.

### 2.3 Concrete Sample Quests
Tersimpan di direktori `resources/quests/`:
1. **`quest_first_steps.tres` ("Langkah Pertama Petualang"):**
   - Pemberi: `npc_guide` ("Pemandu Kampus").
   - Prasyarat: Tidak ada (Tersedia sejak awal).
   - Objektif:
     1. Kalahkan 2 Dummy Slime (`kill_slimes`, target `dummy_slime`, qty 2).
     2. Kumpulkan 2 Slime Jelly (`collect_jelly`, target `slime_jelly`, qty 2).
     3. Bicara dengan Pemandu Kampus (`talk_guide`, target `npc_guide`, qty 1).
   - Hadiah: 150 EXP, 1x Health Potion, 1x Dungeon Key (`dungeon_key`).
2. **`quest_dungeon_boss.tres` ("Penjaga Labirin Bawah Tanah"):**
   - Pemberi: `npc_guide`.
   - Prasyarat: Menyelesaikan `quest_first_steps`.
   - Objektif: Kalahkan Boss Gorgon (`kill_boss`, target `boss_gorgon`, qty 1).
   - Hadiah: 500 EXP, 1x Iron Sword.

---

## 3. Event-Driven Quest Manager & Deduplication

### 3.1 Arsitektur Scoped Singleton `QuestManager`
`QuestManager` (`scripts/systems/quest_manager.gd`) bertindak sebagai pengendali utama seluruh alur quest:
- Menyediakan akses via singleton `QuestManager.get_instance()` dan terhubung secara otomatis ke scene level via `WorldBase`.
- Menyediakan API lengkap: `register_quest`, `can_accept_quest`, `accept_quest`, `update_objective_progress`, `complete_quest`, dan `claim_reward`.

### 3.2 Idempotency & Deduplication Cache
Dalam pertempuran intensif, musuh yang terkena beberapa hitbox dapat memicu sinyal ganda dalam hitungan millidetik. `QuestManager` menerapkan mekanisme deduplikasi berlapis:
- `_processed_enemy_instances`: Mencatat `enemy_instance_id` unik dari setiap musuh yang mati via `enemy_defeated_at`. Jika ID yang sama diterima kembali, event diabaikan.
- Cache dibersihkan secara bounded (`_clean_cache_if_needed(cache, 150)`) untuk menjaga konsumsi memori tetap stabil.
- Mendukung pembaruan multi-quest secara simultan dari satu event (misal: membunuh slime dapat memajukan dua quest aktif yang sama-sama menargetkan slime).

### 3.3 Multi-Slot Atomic Reward Claim
Klaim hadiah quest dirancang dengan integritas transaksional atomik untuk mencegah bug kehilangan item:
- Sebelum mendistribusikan hadiah, `QuestManager.claim_reward()` menghitung kebutuhan slot kosong secara konkuren:
  - Memeriksa kapasitas sisa pada tumpukan stack item sejenis yang sudah ada di inventaris (`existing_stack_space`).
  - Menghitung sisa kuantitas yang memerlukan slot kosong baru (`needed_empty_slots += ceili(remaining / max_stack)`).
- Jika `inventory.get_free_slot_count() < needed_empty_slots`, transaksi DITOLAK SEPENUHNYA:
  - Status quest tetap `COMPLETED` (tidak bergeser ke claimed).
  - Tidak ada item yang dimasukkan dan tidak ada EXP yang diberikan.
  - Memunculkan notifikasi visual: *"Inventaris Penuh! Hadiah belum dapat diambil."*
- Jika ruang mencukupi, seluruh item dimasukkan, EXP diberikan, status bergeser ke `REWARD_CLAIMED`, dan sinyal `quest_reward_claimed` dipancarkan. Operasi klaim kedua pada quest yang sama otomatis ditolak (*anti double-claim*).

---

## 4. NPC & Dialogue System

### 4.1 DialogueData & DialogueUI
- **`DialogueData` (`scripts/resources/dialogue_data.gd`):** Custom Resource yang menyimpan `speaker_name`, array kalimat `lines`, dan referensi `quest_to_give` serta `quest_to_complete`.
- **`DialogueUI` (`scripts/ui/dialogue_ui.gd` & `scenes/ui/dialogue_ui.tscn`):**
  - Berada pada CanvasLayer 25 (di atas gameplay HUD).
  - Menampilkan panel dialog pixel-art berlatar semi-transparan, nama pembicara, label teks baris per baris, dan tombol navigasi 'Lanjut [E]' / 'Selesai'.
  - Mendukung input keyboard (tombol `E`, `Space`, `Enter`, `Esc`) dan klik tombol sentuh mobile.
  - Memancarkan sinyal `opened(dialogue_id)` dan `closed(dialogue_id)`.

### 4.2 Modal Player Input Lock
Ketika dialog dibuka:
- `GameManager.change_state(GameManager.GameState.DIALOGUE)` diaktifkan.
- `player.is_input_locked = true` disetel:
  - Vektor input gerakan dinolkan (`velocity = Vector2.ZERO`).
  - Tombol aksi serang (`attack`), menghindar (`dodge`), dan interaksi (`interact`) diblokir di level `Player`.
- Ketika dialog selesai ditutup, `player.is_input_locked = false` dipulihkan dan game state kembali ke `GameState.PLAYING`.
- Jika dialog membawa `quest_to_give`, quest tersebut otomatis diterima oleh `QuestManager`.

### 4.3 Stateful NPC Entity (`scenes/entities/npc.tscn`)
- Menggunakan `CharacterBody2D` pada Physics Layer 5 (Body: 16) dan memiliki `Interactable` (Layer 8: 128) dengan radius 24 px.
- Menangani pemilihan dialog secara adaptif berdasarkan progres quest pemain:
  1. Jika quest belum diambil: menampilkan `default_dialogue` dan menawarkan quest.
  2. Jika quest sedang aktif: menampilkan `active_quest_dialogue` (mengingatkan tujuan quest).
  3. Jika quest telah selesai: menampilkan `completed_quest_dialogue`.
- Setiap kali diajak berbicara, NPC memancarkan `EventBus.npc_interacted(npc_id)`, memajukan objektif tipe `TALK_TO_NPC`.

---

## 5. Dungeon & Key System

### 5.1 Dungeon Key Item Resource
- Berkas: `resources/items/dungeon_key.tres`.
- Tekstur: Aset pixel art kunci emas 16x16 (`assets/items/dungeon_key.png`).
- Tipe: `ItemType.QUEST`, Rarity: `RARE`, Max Stack: 99.

### 5.2 Dungeon Door (`scenes/objects/dungeon_door.tscn`)
- Turunan `Node2D` yang mengintegrasikan `Interactable` (Layer 8: 128).
- Logika Interaksi:
  - Jika `is_locked == true`:
    - Memeriksa apakah `player.inventory_manager.has_item(required_key_id)` bernilai true.
    - Jika tidak ada kunci: interaksi membatalkan perpindahan, memancarkan sinyal `unlock_failed`, dan menampilkan floating text *"Pintu terkunci! Membutuhkan Kunci Labirin."*
    - Jika ada kunci: pintu terbuka, mengonsumsi 1 kunci dari inventaris (jika `consumes_key = true`), memancarkan floating text *"Pintu berhasil dibuka dengan Kunci Labirin!"*, dan memperbarui prompt interaktif.
  - Memindahkan pemain ke `target_scene_path` (`scenes/dungeon/dungeon_room.tscn`) pada spawn marker `dungeon_entrance` via `SceneManager.change_scene_with_spawn()`.
  - Dilengkapi proteksi transisi (*transition lock*) untuk mencegah pemanggilan ganda saat proses fade berjalan.

### 5.3 Dungeon Room Level (`scenes/dungeon/dungeon_room.tscn`)
- Turunan `WorldBase` (`scripts/world/dungeon_room.gd`), `level_name = "Labirin Bawah Tanah Untidar"`.
- Dilengkapi:
  - `TileMapLayer` lantai ruang bawah tanah.
  - `WorldBoundaries` solid di sekeliling ruangan (360x300 px).
  - Pintu keluar `ExitDoor` (`scenes/objects/door.tscn`) yang menghubungkan kembali ke kampus luar (`outdoor_test.tscn`) pada spawn point `from_dungeon`.
  - Peti harta karun boss `TreasureChest` (`dungeon_boss_chest`).
  - Entitas Boss `BossEnemy` di tengah arena.

---

## 6. Two-Phase Boss Encounter (`BossEnemy`)

### 6.1 Spesifikasi Boss Gorgon
- Berkas Skrip: `scripts/enemy/boss_enemy.gd` (turunan `BaseEnemy`).
- Berkas Scene: `scenes/enemy/boss_enemy.tscn`.
- Aset Visual: Sprite monster iblis bertanduk 32x32 pixel art (`assets/enemies/boss_gorgon.png`).
- Parameter Dasar:
  - `enemy_id`: `&"boss_gorgon"`
  - `enemy_name`: `"Gorgon Penjaga Labirin"`
  - `max_health`: 200 HP
  - `defense`: 4 DEF
  - `move_speed`: 50.0 px/s
  - `attack_range`: 36.0 px
  - `attack_cooldown`: 1.2 detik
  - `base_damage`: 20 ATK
  - `knockback_force`: 140.0 px/s
  - `exp_reward`: 500 EXP
  - `loot_table`: `resources/enemies/boss_gorgon_loot.tres`

### 6.2 Two-Phase Enrage Transition
Boss mengimplementasikan perubahan fase tempur secara dinamis saat kesehatannya menurun:
- **Ambang Batas Enrage:** Ketika rasio HP $\le 0.5$ (HP $\le 100$).
- **Peningkatan Status Fase 2:**
  - Kecepatan gerak (`move_speed` & `VelocityComponent.max_speed`) meningkat menjadi **75.0 px/s** (+50%).
  - Kerusakan serang (`base_damage` & `HitboxComponent.damage`) meningkat menjadi **30 ATK** (+50%).
  - Cooldown serang berkurang menjadi **0.7 detik** (serangan lebih agresif).
  - Modulasi visual: Berubah warna menjadi aura merah membara (`Color(1.3, 0.45, 0.45)`) melalui Tween halus.
  - Memancarkan sinyal `enraged` dan `phase_changed(2)`.
  - Dilengkapi guard `is_enraged = true` sehingga transisi fase hanya terjadi tepat 1 kali.

### 6.3 Siklus Kematian & Reward Integritas
- Ketika HP Boss mencapai 0, `BaseEnemy._on_died()` dieksekusi:
  - AI StateMachine dan hitbox/hurtbox langsung dinonaktifkan secara aman.
  - Memancarkan `enemy_defeated_at` dan `enemy_defeated` tepat satu kali membawa `instance_id` unik.
  - Memancarkan EXP 500 dan memunculkan loot drop dari `boss_gorgon_loot.tres` (100% Iron Sword, 2-3x Health Potion, 3-5x Slime Jelly).
  - Memajukan objektif `kill_boss` pada quest `quest_dungeon_boss`.

---

## 7. Quest User Interface & Controls

### 7.1 Panel Quest Log (`QuestUI`)
- Berkas: `scripts/ui/quest_ui.gd` dan `scenes/ui/quest_ui.tscn`.
- Ditempatkan pada CanvasLayer 24 (di bawah DialogueUI Layer 25, di atas HUD Layer 5).
- Fitur UI:
  1. **Tab Navigation:** Tombol tab "Quest Aktif" dan "Quest Selesai".
  2. **Daftar Quest:** Menampilkan daftar tombol quest dengan penanda status `[SELESAI]` atau `[KLAIM]`.
  3. **Panel Detail:** Menampilkan judul quest, nama pemberi tugas, narasi deskripsi, checklist objektif dinamis (`[✓]` hijau atau `[ ]` putih) beserta rasio progres `(current/required)`, dan rincian hadiah (EXP berwarna emas, item berwarna biru langit).
  4. **Tombol Klaim Hadiah:** Tombol "Klaim Hadiah" otomatis muncul dan aktif hanya ketika status quest adalah `COMPLETED`. Jika hadiah sudah diambil, tombol menampilkan teks disabled *"Hadiah Sudah Diklaim"*.
  5. **Toast Notification:** Panel notifikasi melayang di bagian atas layar yang otomatis muncul saat quest baru diterima, objektif selesai, atau hadiah berhasil diklaim (animasi fade in/out via Tween).

### 7.2 Kendali Keyboard & Touchscreen
- **Keyboard Shortcut:** Tombol `Q` terdaftar pada InputMap `quest_log` untuk toggle buka/tutup Quest Log. Tombol `Escape` atau `ui_cancel` menutup panel saat terbuka.
- **Touch Controls Integration:** Menambahkan tombol `%QuestButton` ("QUEST") di pojok kanan atas `TouchControls` berdampingan dengan tombol tas ("TAS"). Menekan tombol ini memancarkan action `quest_log` secara transparan.

---

## 8. Verification & Test Results

Pengujian otomatis dilakukan menggunakan Godot Headless Engine pada dua test suite baru yang mencakup 137 assertions:

### 8.1 Automated Unit Tests (`tests/test_phase_6.gd`)
Menjalankan 93 assertions evaluasi komponen mandiri:
```
=======================================================
>>> STARTING PHASE 6 AUTOMATED VALIDATION SUITE <<<
=======================================================
--- 1. Testing Quest Resources & Validation --- [14 PASS]
--- 2. Testing QuestRuntimeState Decoupling & Clamping --- [12 PASS]
--- 3. Testing QuestManager Lifecycle & Prerequisites --- [12 PASS]
--- 4. Testing Event-Driven Quest Progress & Deduplication --- [6 PASS]
--- 5. Testing Quest Reward Atomic Claims --- [12 PASS]
--- 6. Testing DialogueData & NPC Interaction --- [6 PASS]
--- 7. Testing Dungeon Key & DungeonDoor Mechanics --- [7 PASS]
--- 8. Testing BossEnemy Two-Phase Mechanics --- [20 PASS]
--- 9. Testing QuestUI Representation --- [4 PASS]
=======================================================
>>> PHASE 6 VALIDATION SUMMARY <<<
Passed: 93
Failed: 0
=======================================================
[SUCCESS] All Phase 6 quest & dungeon systems validated with 0 errors!
```

### 8.2 Runtime Multi-Frame Simulation (`tests/runtime_validation_phase_6.gd`)
Menjalankan 44 assertions simulasi runtime fisika nyata:
```
=======================================================
>>> STARTING PHASE 6 RUNTIME SIMULATION SUITE <<<
=======================================================
--- 1. Testing Runtime NPC Dialogue & Player Input Locking --- [8 PASS]
--- 2. Testing Event-Driven Quest Objectives (Kill, Collect, Talk) --- [6 PASS]
--- 3. Testing QuestUI Reward Claiming & Dungeon Key Grant --- [7 PASS]
--- 4. Testing DungeonDoor Key Validation & Unlock --- [8 PASS]
--- 5. Testing Boss Gorgon Two Phases, Enrage & Defeat --- [15 PASS]
=======================================================
>>> PHASE 6 RUNTIME SIMULATION SUMMARY <<<
Passed: 44
Failed: 0
=======================================================
[SUCCESS] All Phase 6 runtime simulations passed with 0 errors!
```

### 8.3 Full Project Regression Matrix (Phase 1–6)
Seluruh 10 test suite proyek dijalankan secara headless untuk menjamin 100% backward compatibility:

| No. | Test Suite File | Deskripsi Cakupan Pengujian | Assertions Passed | Status |
| :---: | :--- | :--- | :---: | :---: |
| 1 | `tests/test_phase_1.gd` | Project Foundation, Settings, Input, Autoloads, Components | 45 / 45 | **PASS** |
| 2 | `tests/test_phase_2.gd` | Player FSM, Movement, ModularVisuals, Touch Controls | 73 / 73 | **PASS** |
| 3 | `tests/test_phase_3.gd` | World, TileMapLayers, Y-Sort, Interactables, Modal Dialog | 91 / 91 | **PASS** |
| 4 | `tests/runtime_validation_phase_3.gd` | Physics Collisions, Y-Sort Math, Scene Transitions | 78 / 78 | **PASS** |
| 5 | `tests/test_phase_4.gd` | Combat Collision Matrix, Damage/Defense, FSM, Arena | 97 / 97 | **PASS** |
| 6 | `tests/runtime_validation_phase_4.gd` | Runtime Attack/Combo, Knockback Decay, Aggro AI, Death | 47 / 47 | **PASS** |
| 7 | `tests/test_phase_5.gd` | Items, Inventory Stacking/Swaps, Stats, Loot Tables | 182 / 182 | **PASS** |
| 8 | `tests/runtime_validation_phase_5.gd` | Runtime Loot Drops, Ground Pickup, Health Potion Sync | 58 / 58 | **PASS** |
| 9 | `tests/test_phase_6.gd` | Quest Data, Manager, Dialogue, Key, Boss 2-Phases, QuestUI | 93 / 93 | **PASS** |
| 10 | `tests/runtime_validation_phase_6.gd` | Runtime Dialogue Input Lock, Door Unlock, Boss Enrage | 44 / 44 | **PASS** |
| **TOTAL** | **10 Test Suites** | **Seluruh Sistem Permainan Petualang Untidar** | **708 / 708** | **100% PASS** |

---

## 9. Deliverables Summary

Berikut adalah daftar berkas baru dan modifikasi yang telah dibuat pada Phase 6:

### Berkas Baru:
1. `scripts/resources/quest_objective_data.gd`: Resource blueprint objektif quest.
2. `scripts/resources/quest_data.gd`: Resource blueprint definisi quest dan reward.
3. `scripts/systems/quest_runtime_state.gd`: Pengelolaan state runtime quest decoupled.
4. `scripts/systems/quest_manager.gd`: Scoped singleton pengelola quest, deduplikasi, dan reward atomik.
5. `scripts/resources/dialogue_data.gd`: Resource teks dialog NPC dan quest triggers.
6. `scripts/ui/dialogue_ui.gd` & `scenes/ui/dialogue_ui.tscn`: CanvasLayer UI percakapan multiline.
7. `scripts/entities/npc.gd` & `scenes/entities/npc.tscn`: Entitas NPC stateful dengan Interactable Layer 8.
8. `assets/items/dungeon_key.png` & `resources/items/dungeon_key.tres`: Aset & resource kunci labirin.
9. `assets/enemies/boss_gorgon.png` & `resources/enemies/boss_gorgon_loot.tres`: Aset & loot table boss.
10. `scripts/enemy/boss_enemy.gd` & `scenes/enemy/boss_enemy.tscn`: Entitas Boss Gorgon 2-fase.
11. `scripts/objects/dungeon_door.gd` & `scenes/objects/dungeon_door.tscn`: Pintu dungeon berkunci.
12. `scripts/world/dungeon_room.gd` & `scenes/dungeon/dungeon_room.tscn`: Level ruang boss bawah tanah.
13. `scripts/ui/quest_ui.gd` & `scenes/ui/quest_ui.tscn`: CanvasLayer UI Quest Log dan klaim hadiah.
14. `resources/quests/quest_first_steps.tres`: Quest 1 konkret (Langkah Pertama Petualang).
15. `resources/quests/quest_dungeon_boss.tres`: Quest 2 konkret (Penjaga Labirin Bawah Tanah).
16. `tests/test_phase_6.gd`: Unit validation test suite Phase 6 (93 tests).
17. `tests/runtime_validation_phase_6.gd`: Multi-frame runtime simulation suite Phase 6 (44 tests).

### Berkas Dimodifikasi:
1. `scripts/autoload/event_bus.gd`: Penambahan sinyal `quest_accepted`, `quest_reward_claimed`, `npc_interacted`.
2. `scripts/player/player.gd`: Penambahan flag `is_input_locked`, penahanan input saat dialog, integrasi QuestManager.
3. `scripts/enemy/base_enemy.gd`: Penjagaan tree state pada `get_node_or_null` dan `create_tween()`.
4. `scripts/world/world_base.gd`: Auto-instansiasi `DialogueUI` dan `QuestUI` di HUD, registrasi default quests.
5. `scripts/ui/touch/touch_controls.gd` & `scenes/ui/touch_controls.tscn`: Penambahan tombol mobile `%QuestButton`.
6. `scenes/world/outdoor_test.tscn`: Penempatan NPC Guide, DungeonDoor, dan spawn point `from_dungeon`.
7. `docs/development/roadmap.md`: Pembaruan status Phase 6 menjadi COMPLETED.
8. `docs/architecture/technical-architecture.md`: Penambahan arsitektur teknis Quest, Dialogue, Dungeon, & Boss.
9. `docs/decisions/technical-decisions.md`: Penambahan ADR-023, ADR-024, ADR-025.

---

## 10. Conclusion & Next Steps

Seluruh persyaratan fungsional, arsitektural, dan stabilitas pada **Phase 6: Quest & Dungeon System** telah terpenuhi 100%. Sistem quest terbukti tahan banting terhadap eksploitasi duplikasi event, transaksi klaim hadiah bekerja secara atomik dan melindungi barang pemain saat tas penuh, percakapan NPC mengunci kontrol pemain secara mulus, pintu labirin terlindungi oleh kepemilikan kunci dungeon, dan pertempuran boss dua fase berjalan dinamis dan stabil.

Sesuai instruksi batas pengerjaan, **Phase 7 (UI & Persistence) TIDAK DIMULAI**. Repositori kini siap untuk di-commit dan di-push ke branch `main`.
