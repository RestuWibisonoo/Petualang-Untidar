# Technical Architecture: Petualang Untidar

- **Dokumen:** Arsitektur Teknis Sistem Game
- **Target Versi Engine:** Godot Engine 4.7.2
- **Bahasa Pemrograman:** GDScript (Strict Typing 2.0)
- **Target Platform:** Web (HTML5/Wasm) & Android (APK/AAB)
- **Genre:** 2D Top-Down Action Adventure RPG
- **Status:** APPROVED BLUEPRINT (Menunggu implementasi Phase 1)

---

## 1. Overall Game Architecture

Proyek *Petualang Untidar* menerapkan pola gabungan **Composition over Inheritance (Entity-Component Lite)**, **Resource-Driven Architecture**, dan **Event-Driven Communication**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION / UI LAYER                         │
│  HUD | Dynamic Virtual Joystick | Inventory UI | Dialogue | Floating FX │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Sinyal Global / Direct Binding
┌───────────────────────────────────┴────────────────────────────────────┐
│                        GAMEPLAY ENTITIES LAYER                         │
│  PlayerEntity | EnemyEntity | NPCEntity | Interactables | Projectiles  │
│  ├─ StateMachine (FSM: Idle, Move, Attack, Roll, Hurt, Dead)          │
│  ├─ Core Components (Health, Velocity, Hitbox, Hurtbox, Interaction)   │
│  └─ Modular Visual Controller (8-Dir Synchronized Layer Rig)          │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Membaca & Mengolah
┌───────────────────────────────────┴────────────────────────────────────┐
│                        RESOURCE / DATA LAYER                           │
│  CharacterStats.tres | ItemData.tres | EquipmentData.tres | Quests    │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Dikelola & Disimpan oleh
┌───────────────────────────────────┴────────────────────────────────────┐
│                        AUTOLOAD / CORE MANAGERS                        │
│  EventBus | GameManager | DataManager | SceneManager | AudioManager    │
└────────────────────────────────────────────────────────────────────────┘
```

### Prinsip Utama:
1. **Node Composition:** Entity dasar (`Player`, `Enemy`) menggunakan `CharacterBody2D` tipis. Seluruh logika (darah, pergerakan, deteksi tabrakan serang) dipecah menjadi komponen Node mandiri.
2. **Ketergantungan Longgar (*Loose Coupling*):** Sinyal berjalan ke atas (*signals up*), pemanggilan fungsi langsung hanya ke bawah (*calls down*). Komunikasi lintas sistem tak bertetangga dijembatani oleh `EventBus`.
3. **Data-Driven Execution:** Semua statistik karakter, tabel loot, katalog item, dan quest disimpan sebagai Godot Custom Resource (`.tres`), bukan ditulis *hardcoded* di dalam script node.

---

## 2. Core Systems

### 2.1 Finite State Machine (FSM)
Setiap entitas yang memiliki perilaku dinamis dikendalikan oleh hierarki FSM sederhana berbasis node:

* **`State.gd` (`extends Node`):**
  * `enter(msg: Dictionary = {}) -> void`
  * `exit() -> void`
  * `physics_update(delta: float) -> void`
  * `handle_input(event: InputEvent) -> void`
* **`StateMachine.gd` (`extends Node`):**
  * Menyimpan referensi state aktif saat ini (`current_state: State`).
  * Menyediakan method `transition_to(target_state_name: StringName, msg: Dictionary = {})`.
  * Memastikan hanya satu status yang aktif mengeksekusi logika fisika per frame.

### 2.2 Reusable Core Components
Setiap komponen memiliki tanggung jawab tunggal (*Single Responsibility Principle*):

| Komponen | Tipe Node Induk | Fungsi Utama |
| :--- | :--- | :--- |
| **`HealthComponent`** | `Node` | Menyimpan HP saat ini, batas HP maksimal, sinyal pengurangan/penambahan darah, dan emisi sinyal kematian (`died`). |
| **`VelocityComponent`** | `Node` | Mengatur kalkulasi akselerasi, gesekan (*friction*), deselerasi, dan kecepatan maksimum untuk pergerakan 8 arah. |
| **`HitboxComponent`** | `Area2D` | Mengirim damage, knockback vector, dan efek status kepada Hurtbox lawan. |
| **`HurtboxComponent`** | `Area2D` | Menerima damage dari Hitbox lawan, memicu frames kebal (*invincibility frames/i-frames*), dan meneruskan damage ke `HealthComponent`. |
| **`InteractionComponent`** | `Area2D` | Mendeteksi objek di dunia (NPC, pintu, peti, item drop) yang dapat diinteraksi dengan tombol aksi. |

---

## 3. Scene Architecture

### 3.1 Hierarki Node Pemain (`player.tscn`)
Pemisahan visual modular, fisika, dan deteksi area:

```text
Player (CharacterBody2D) [Script: player.gd]
├── CollisionShape2D (Kapsul horizontal kecil di area kaki)
├── ModularVisuals (Node2D) [Script: modular_visuals.gd]
│   ├── Shadow (Sprite2D)
│   ├── WeaponBack (Sprite2D)
│   ├── Body (Sprite2D)
│   ├── Pants (Sprite2D)
│   ├── Clothes (Sprite2D)
│   ├── Armor (Sprite2D)
│   ├── Head (Sprite2D)
│   ├── Hair (Sprite2D)
│   ├── Accessory (Sprite2D)
│   ├── WeaponFront (Sprite2D)
│   └── AnimationPlayer (Pengendali sinkronisasi seluruh frame layer)
├── StateMachine (Node) [Script: state_machine.gd]
│   ├── Idle (Node) [Script: player_idle_state.gd]
│   ├── Move (Node) [Script: player_move_state.gd]
│   ├── Attack (Node) [Script: player_attack_state.gd]
│   ├── Roll (Node) [Script: player_roll_state.gd]
│   └── Hurt (Node) [Script: player_hurt_state.gd]
├── HealthComponent (Node) [Script: health_component.gd]
├── VelocityComponent (Node) [Script: velocity_component.gd]
├── HitboxComponent (Area2D - Collision: Layer 4, Mask: Layer 5)
│   └── CollisionShape2D
├── HurtboxComponent (Area2D - Collision: Layer 3, Mask: Layer 6)
│   └── CollisionShape2D
├── InteractionDetector (Area2D - Collision: Layer 0, Mask: Layer 7)
│   └── CollisionShape2D
└── Camera2D (Position Smoothing, Pixel Snap, Viewport Limits)
```

### 3.2 Struktur Dunia Game (`world.tscn`)
Godot 4.3+ dan 4.7 menstandarisasi `TileMapLayer`:

```text
World (Node2D)
├── GroundLayer (TileMapLayer - Rumput, jalan, lantai tanpa collision)
├── WallDecoLayer (TileMapLayer - Dinding bawah, dekorasi tanah)
├── YSortEntities (Node2D - y_sort_enabled = true)
│   ├── SolidObjectsLayer (TileMapLayer - Bangunan bercollision dengan y-sort)
│   ├── Player (Instanced Scene)
│   ├── Enemies (Node2D penampung musuh)
│   ├── NPCs (Node2D penampung NPC)
│   └── DroppedItems (Node2D penampung loot di tanah)
├── OverheadLayer (TileMapLayer - Atap gedung, kanopi pohon di atas karakter)
├── CanvasModulate (Pewarnaan siklus siang-malam / pencahayaan)
└── UI_CanvasLayer (CanvasLayer - Lapisan HUD dan Kontrol Sentuh)
```

---

## 4. Autoload / Singleton Design

Hanya terdapat **5 Autoload inti** yang diizinkan untuk mencegah ketergantungan yang rumit (*spaghetti state*):

```
┌─────────────────────────────────────────────────────────────┐
│                           AUTOLOAD                          │
├─────────────────┬───────────────────────────────────────────┤
│ EventBus        │ Pusat sinyal global antar modul UI & game │
│ GameManager     │ State siklus permainan (Play, Pause, Menu)│
│ DataManager     │ Save / Load / Profil Pemain ke Storage    │
│ SceneManager    │ Transisi scene dan loading asynchronous   │
│ AudioManager    │ Manajemen BGM, SFX, dan Web Audio Unlock  │
└─────────────────┴───────────────────────────────────────────┘
```

### Rincian Sinyal & Tanggung Jawab:

1. **`EventBus.gd`**
   * `player_health_changed(current: int, max_val: int)`
   * `player_stamina_changed(current: float, max_val: float)`
   * `inventory_updated()`
   * `item_equipped(slot: StringName, item: EquipmentData)`
   * `quest_status_changed(quest_id: StringName, status: int)`
   * `enemy_defeated(enemy_id: StringName)`
   * `show_floating_text(text: String, world_position: Vector2, color: Color)`

2. **`GameManager.gd`**
   * Mengatur enum status game: `STATE_BOOT`, `STATE_MAIN_MENU`, `STATE_PLAYING`, `STATE_PAUSED`, `STATE_DIALOGUE`, `STATE_GAME_OVER`.
   * Mengatur `get_tree().paused` secara aman saat menu atau dialog terbuka tanpa mematikan animasi UI.

3. **`DataManager.gd`**
   * Mengatur serialisasi status pemain ke file `user://savegame.json`.
   * Menyediakan fungsi verifikasi checksum sederhana untuk mencegah file korup.

4. **`SceneManager.gd`**
   * Menggunakan `ResourceLoader.load_threaded_request()` untuk memuat level baru tanpa *screen freezing*.
   * Memiliki layer `ColorRect` independen untuk efek fade-to-black.

5. **`AudioManager.gd`**
   * Mengelola Audio Bus (`Master`, `BGM`, `SFX`).
   * Mengatasi batasan browser Web: Menahan pemutaran BGM otomatis sampai pengguna melakukan sentuhan atau klik pertama di kanvas.

---

## 5. Modular Character Architecture & Animation

### 5.1 Urutan Penumpukan Layer Visual (Z-Order)
Visual karakter disusun dalam 10 layer berurutan (dari paling belakang ke paling depan):

1. **`Shadow`**: Bayangan oval semi-transparan di tanah.
2. **`WeaponBack`**: Senjata dua tangan / busur / tameng saat disarungkan di punggung.
3. **`Body`**: Tekstur kulit dan tubuh dasar.
4. **`Pants`**: Celana pendek / celana panjang / rok.
5. **`Clothes`**: Pakaian dasar / kemeja dalam.
6. **`Armor`**: Rompi zirah / jubah / pakaian luar.
7. **`Head`**: Ekspresi wajah dan mata.
8. **`Hair`**: Rambut atau helm pelindung kepala.
9. **`Accessory`**: Kacamata, syal, ransel, atau aksesoris wajah.
10. **`WeaponFront`**: Senjata utama di tangan (pedang, tongkat sihir, pisau).

### 5.2 Standarisasi Grid Sprite
* Seluruh tekstur modular wajib menggunakan rasio kanvas dan tata letak frame yang **100% seragam** (misalnya grid 32x32 atau 48x48 pixel per frame).
* **Mekanisme Sinkronisasi:** Hanya ada **1 node `AnimationPlayer`** pada node `ModularVisuals`. Node ini mengontrol nilai properti `frame` atau baris/kolom sprite. Ketika `AnimationPlayer` berpindah ke frame berikutnya, seluruh `Sprite2D` di layer tubuh, pakaian, dan senjata berganti serentak tanpa perlu script individual di tiap pakaian.

### 5.3 Sistem 8-Arah Gerakan (8-Directional Mapping)
Vektor input kontinu dari keyboard atau joystick (`Vector2`) dipetakan ke 8 sektor arah diskrit (masing-masing 45°):

```
       [up]
 [up_left]   [up_right]
[left]           [right]
 [down_left] [down_right]
      [down]
```

Nama animasi disusun secara standar dengan format: `<action>_<direction>`
Contoh:
* `idle_down`, `idle_up`, `idle_right`, `idle_up_right`...
* `walk_down`, `walk_up`, `walk_right`, `walk_up_right`...
* `attack_down`, `attack_up`, `attack_right`...
* `roll_down`, `roll_up`, `roll_right`...

*(Arah kiri dapat menggunakan flip horizontal atau menggunakan frame gambar terdedikasi untuk menjaga konsistensi arah pencahayaan dan bayangan pixel art).*

---

## 6. Resource / Data Architecture

Seluruh data permainan didefinisikan menggunakan Godot Custom Resource berorientasi tipe data ketat:

### 6.1 Hirarki Resource
```
Resource
 ├── CharacterStats (Darah, stamina, attack, defense, move speed, modifiers)
 ├── ItemData (ID, nama, deskripsi, icon, item_type, max_stack, harga)
 │    └── EquipmentData (Slot, stat_bonuses, visual_texture_atlas)
 ├── EnemyData (ID, nama, base_stats, ai_behavior, drop_table, exp_reward)
 └── QuestData (ID, judul, objectives, rewards, prerequisite_quests)
```

### 6.2 Enums Standar
* **`ItemType`**: `CONSUMABLE`, `EQUIPMENT`, `MATERIAL`, `QUEST`.
* **`EquipmentSlot`**: `WEAPON`, `ARMOR_BODY`, `PANTS`, `HAIR_HELM`, `ACCESSORY`.
* **`Rarity`**:
  * `COMMON` (Warna `#FFFFFF` / Putih)
  * `UNCOMMON` (Warna `#4CAF50` / Hijau)
  * `RARE` (Warna `#2196F3` / Biru)
  * `EPIC` (Warna `#9C27B0` / Ungu)
  * `LEGENDARY` (Warna `#FF9800` / Oranye Emas)

---

## 7. Input System (Cross-Platform)

Game mendukung kendali transparan antara Desktop (Keyboard/Mouse), Gamepad, dan Mobile (Touchscreen):

```
[Hardware Inputs]                                [Virtual Inputs]
WASD / Arrow Keys ────────┐              ┌──── Dynamic Touch Joystick
Gamepad Analog/D-Pad ─────┼──► Unified  ◄┼──── Touch Action Buttons
J / Space / Enter ────────┘    Input     └──── Canvas Touch Events
                               Handler
                                  │
                       Emits Normalized Vector2
                         & Standard Actions
```

* **Action Mappings di `project.godot`:**
  * `move_up`, `move_down`, `move_left`, `move_right`
  * `attack` (J / Left Click / Gamepad X / Touch Button A)
  * `roll` (Space / Gamepad B / Touch Button B)
  * `interact` (E / Gamepad Y / Touch Button X)
  * `inventory` (I / Gamepad Select)
  * `pause` (Escape / Gamepad Start)
* **Virtual Joystick Android/Web Touch:**
  * Menggunakan sistem *Dynamic Floating Joystick*: zona sentuh sisi kiri layar memunculkan analog di titik sentuh pertama jari, mencegah kelelahan tangan pemain.
  * Node UI kontrol sentuh secara otomatis mendeteksi ketersediaan layar sentuh (`DisplayServer.is_touchscreen_available()`) dan menyembunyikan dirinya jika dijalankan di PC dengan mouse/keyboard murni.

---

## 8. Save / Load Architecture

* **Lokasi Penyimpanan:** `user://savegame.json`
* **Strategi Serialisasi:**
  * Komponen yang menyimpan data mengimplementasikan interface `get_save_data() -> Dictionary` dan `load_save_data(data: Dictionary) -> void`.
  * `DataManager` mengumpulkan data dari:
    1. Info Pemain (Level, EXP, posisi koordinat dunia, nama map aktif).
    2. Statistik Terkini (Current HP, Stamina).
    3. Inventaris & Equipment Terpasang.
    4. Status Quest (Daftar quest aktif dan komplit).
    5. State Lingkungan (Peti harta yang sudah dibuka, NPC yang sudah diajak bicara).
* **Keamanan Data:** Menyimpan hash checksum sederhana di akhir file untuk mendeteksi manipulasi data atau file save yang rusak saat crash.

---

## 9. Platform Architecture (Web & Android)

| Tantangan Teknis | Spesifikasi Solusi |
| :--- | :--- |
| **WebGL 2.0 Shader Limit** | Menggunakan renderer `gl_compatibility`. Hindari fitur komputasi shader (*compute shaders*) dan post-processing berat. |
| **Penyimpanan Web Browser** | Memanfaatkan IndexedDB via `user://` bawaan engine. Ditambahkan opsi export teks base64 untuk cadangan manual pengguna. |
| **Android Notch / Safe Area** | Menggunakan API `DisplayServer.get_display_cutouts()` untuk menambahkan padding otomatis pada UI CanvasLayer. |
| **Kinerja Baterai Android** | Batasi target framerate maksimum ke 60 FPS (`Engine.max_fps = 60`) untuk mencegah panas berlebih (*thermal throttling*). |
| **Pixel Art Aspect Ratio** | Resolusi viewport dasar integer `640x360` dengan black bars (*pillarbox/letterbox*) jika rasio layar ponsel melebihi 16:9. |

