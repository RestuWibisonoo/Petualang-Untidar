# Implementation Report: Phase 4 — Combat System

- **Tanggal Pelaksanaan:** 2026-11-06
- **Status:** COMPLETED & REGRESSION VERIFIED (100% PASS)
- **Pelaksana:** Senior Godot Gameplay Engineer, Combat System Architect & QA Engineer
- **Engine:** Godot Engine 4.7.2 (v4.7.2.stable.official.ed1daf0bf)
- **Bahasa:** GDScript (Strict Typing 2.0)
- **Renderer:** GL Compatibility
- **Target Platform:** Web (HTML5/Wasm) & Android (GLES3/APK)

---

## 1. Task Overview

Mengimplementasikan arsitektur sistem pertarungan (*Combat System*) real-time top-down 2D pada **Phase 4** untuk game *Petualang Untidar* berdasarkan fondasi Phase 1, Phase 2, dan Phase 3 yang telah disetujui:
1. Pembangunan **Collision Matrix 8-Layer** diskrit dan sistem filtering faksi (`Faction { PLAYER = 0, ENEMY = 1, NEUTRAL = 2 }`) untuk eliminasi friendly fire dan self-damage.
2. Implementasi **`PlayerAttackState`** pada Finite State Machine (FSM) pemain dengan pembagian jendela waktu per serangan (Startup 0.08s, Active 0.12s, Recovery 0.10s), combo serang 2-tahap, input buffering, dan orientasi hitbox 8-arah.
3. Pembuatan komponen combat inti yang modular dan reaktif:
   - `HitboxComponent`: tracking target tunggal per tebasan (`_hit_targets`), orientasi arah, aktivasi deferred (`set_deferred("monitorable", val)`).
   - `HurtboxComponent`: otoritas tunggal I-Frames (`is_invulnerable`), kalkulasi pengurangan defense, visual hit flash red modulate, emisi floating damage text, dan delegasi knockback fisik.
   - `VelocityComponent`: integrasi variabel `knockback_velocity` dan gesekan peluruhan `knockback_friction: 800.0 px/s²` ke dalam `apply_to_body()` dan `CharacterBody2D.move_and_slide()` (zero wall clipping).
4. Pembuatan entitas musuh dasar **`BaseEnemy`** (`scenes/enemy/base_enemy.tscn` & `scripts/enemy/base_enemy.gd`) dengan FSM mandiri: `EnemyIdleState`, `EnemyChaseState`, `EnemyAttackState`, dan `EnemyHurtState`.
5. Integrasi kontrol input tempur: Action `attack` pada keyboard (J / Mouse 1) dan tombol aksi sentuh `%AttackButton` pada `TouchControls`.
6. Pembuatan arena pengujian tempur dedicated: **`CombatArena`** (`scenes/world/combat_arena.tscn` & `scripts/world/combat_arena.gd`) terhubung doorway dua arah dengan `outdoor_test.tscn`.
7. Pembangunan suite pengujian komprehensif:
   - `tests/test_phase_4.gd`: Automated unit validation suite (92 assertions, 100% PASS).
   - `tests/runtime_validation_phase_4.gd`: Multi-frame physics & runtime simulation suite (33 assertions, 100% PASS).
   - Regresi total proyek: 412/412 assertions lulus tanpa galat.

---

## 2. Combat Architecture & Collision Matrix

### 2.1 Matriks Tabrakan 8-Layer Diskrit
Untuk mencegah benturan fisik antara tubuh karakter dan kalkulasi area serang, matriks fisika dikonfigurasi secara ketat pada layer 1 hingga 8:

| Layer | Nama Layer | Nilai Bitmask | Deteksi / Mask Target | Keterangan |
| :---: | :--- | :---: | :---: | :--- |
| **Layer 1** | World | `1` | `0` | Dinding solid, rintangan peta, batas arena. |
| **Layer 2** | Player Body | `2` | `17` (`1` + `16`) | Tubuh fisik pemain (terhalang dinding dan musuh). |
| **Layer 3** | Player Hurtbox | `4` | `64` | Area terima serang pemain (hanya mendeteksi Enemy Hitbox). |
| **Layer 4** | Player Hitbox | `8` | `32` | Area serang senjata pemain (hanya mendeteksi Enemy Hurtbox). |
| **Layer 5** | Enemy Body | `16` | `19` (`1` + `2` + `16`) | Tubuh fisik musuh (terhalang dinding, pemain, dan sesama musuh). |
| **Layer 6** | Enemy Hurtbox | `32` | `8` | Area terima serang musuh (hanya mendeteksi Player Hitbox). |
| **Layer 7** | Enemy Hitbox | `64` | `4` | Area serang musuh (hanya mendeteksi Player Hurtbox). |
| **Layer 8** | Interactables | `128` | `0` | Objek dunia interaktif (pintu, papan, peti). |

### 2.2 Faction Filtering
Selain pemisahan layer fisik, `HitboxComponent` dan `HurtboxComponent` mengimplementasikan enum `Faction`:
```gdscript
enum Faction {
    PLAYER = 0,
    ENEMY = 1,
    NEUTRAL = 2
}
```
Aturan validasi:
1. `hitbox.faction == hurtbox.faction` (kecuali `NEUTRAL`) -> Serangan diblokir tanpa kalkulasi damage (anti friendly fire).
2. `hitbox.faction != hurtbox.faction` atau salah satu bertipe `NEUTRAL` -> Serangan diproses secara sah.

---

## 3. Player Combat & 2-Stage Combo System

### 3.1 Timing Windows & Parameter Serangan
`PlayerAttackState` membagi siklus serangan tebasan menjadi 3 jendela waktu berurutan:
- **Startup Window (0.08s):** Hitbox tidak aktif (`is_active = false`). Karakter menyiapkan ancang-ancang ayunan senjata.
- **Active Hit Window (0.12s):** Hitbox aktif (`is_active = true`). Membuka `_combo_window_open = true` untuk input buffering combo lanjutan.
- **Recovery Window (0.10s):** Hitbox dinonaktifkan kembali (`is_active = false`). Menuntaskan tindak lanjut ayunan pedang.

### 3.2 Spesifikasi Combo 2-Tahap:
- **Stage 1 (Slash Awal):**
  - Damage: `15` raw.
  - Knockback Force: `120.0` px/s.
  - Jangkauan: `18.0` px ke arah hadap 8-arah.
- **Stage 2 (Heavy Finisher Combo):**
  - Damage: `25` raw (+66% peningkatan kekuatan).
  - Knockback Force: `200.0` px/s (+66% dorongan impak).
  - Jangkauan: `18.0` px ke arah hadap.
  - Reset kembali ke Stage 1 setelah siklus selesai.

### 3.3 Orientasi Hitbox 8-Arah
Posisi `HitboxComponent` dihitung secara dinamis dari vektor arah hadap pemain:
`hitbox.position = _attack_direction * attack_reach`
Mendukung 8 arah mata angin (`down`, `down_right`, `right`, `up_right`, `up`, `up_left`, `left`, `down_left`).

---

## 4. Base Enemy AI & Lifecycle

### 4.1 Parameter BaseEnemy
- `enemy_id`: `&"dummy_slime"` (identitas unik untuk event tracking).
- `max_health`: `50` HP.
- `defense`: `2` (menyerap 2 poin dari setiap raw damage yang diterima).
- `move_speed`: `50.0` px/s.
- `aggro_radius`: `120.0` px (radius deteksi pemain).
- `deaggro_radius`: `180.0` px (batas pemain meloloskan diri).
- `attack_range`: `24.0` px (jarak picu serangan melee).
- `attack_cooldown`: `1.0` s (timer pendinginan antar serangan musuh).
- `base_damage`: `10` raw (impak 10 damage ke pemain).

### 4.2 FSM Musuh
1. **`EnemyIdleState`:** Diam di tempat, mendiselerasi sisa pergerakan, memindai jarak pemain di dalam `aggro_radius` $\to$ transisi ke `chase`.
2. **`EnemyChaseState`:** Mengejar posisi pemain via `velocity_component.accelerate_in_direction()`. Jika jarak $\le$ `attack_range` dan cooldown siap $\to$ transisi ke `attack`. Jika jarak $>$ `deaggro_radius` $\to$ kembali ke `idle`.
3. **`EnemyAttackState`:** Berhenti bergerak, mengarahkan hitbox ke arah pemain, mengeksekusi jendela startup (0.15s), active (0.15s), dan recovery (0.20s). Mengaktifkan cooldown serang saat selesai.
4. **`EnemyHurtState`:** Terpicu saat menerima damage. Musuh berada dalam kondisi stagger selama 0.25s sembari momentum knockback meluruh secara fisik.

### 4.3 Siklus Kematian & Single Emission Defeat
Saat HP musuh mencapai 0:
1. `is_dead` ditandai `true`.
2. AI StateMachine dimatikan (`set_physics_process(false)`).
3. `collision_shape`, `hitbox_component`, dan `hurtbox_component` dinonaktifkan secara deferred.
4. Sinyal `enemy_defeated(enemy_id)` dipancarkan via `EventBus` **tepat satu kali** (terproteksi dari panggilan ganda).
5. Visual feedback: animasi tween fade-out transparansi dan pengecilan skala (0.3s), kemudian dieksekusi `queue_free()`.

---

## 5. Damage, Knockback & I-Frames Integration

### 5.1 Formula Kalkulasi Damage
$$\text{final\_damage} = \max(0, \text{raw\_damage} - \text{defense})$$
- Jika $\text{raw\_damage} \le \text{defense}$, serangan bernilai 0 damage dan diabaikan (tidak memicu I-frames atau stagger).
- Entitas mati (`current_health <= 0`) tidak memproses hit apapun.

### 5.2 Knockback Fisik Anti-Penembusan Tembok
- Arah knockback dihitung dari posisi penyerang (`attacker_pos`) ke posisi target (`target_pos`):
  $$\vec{d}_{\text{knockback}} = \frac{\vec{p}_{\text{target}} - \vec{p}_{\text{attacker}}}{\|\vec{p}_{\text{target}} - \vec{p}_{\text{attacker}}\|}$$
- Impuls disalurkan ke `VelocityComponent.apply_knockback(\vec{d} \cdot F_{\text{knockback}})`.
- Peluruhan dihitung setiap delta fisika menggunakan `knockback_friction = 800.0` px/s²:
  $$\vec{v}_{\text{knockback}} = \text{move\_toward}(\vec{v}_{\text{knockback}}, \vec{0}, \text{friction} \cdot \Delta t)$$
- Kecepatan total `body.velocity = velocity + knockback_velocity` diproses langsung oleh engine melalui `CharacterBody2D.move_and_slide()`. Hal ini menjamin algoritma tabrakan Godot Physics menghentikan pergerakan di permukaan collider dinding tanpa celah penembusan (*zero wall clipping*).

### 5.3 Otoritas Tunggal I-Frames
- `HurtboxComponent` bertindak sebagai otoritas tunggal status kebal pasca-serang (`is_invulnerable = true`) selama `0.2` detik.
- Mengeliminasi bug multi-tick damage di mana hitbox aktif mengenai target berulang kali dalam frame yang berdekatan.
- `HitboxComponent` menyimpan array `_hit_targets` yang mencatat target yang sudah dikenai dalam satu ayunan senjata.

---

## 6. Files Created & Modified

### A. File Baru Dibuat
* `scripts/enemy/base_enemy.gd`: Controller utama entitas musuh (`class_name BaseEnemy`).
* `scenes/enemy/base_enemy.tscn`: Scene entitas musuh lengkap dengan komponen combat, FSM, dan sprite.
* `scenes/enemies/base_enemy.tscn`: Salinan kompatibilitas direktori jamak.
* `scripts/enemy/states/enemy_idle_state.gd`: State AI idle dan pemindai aggro radius (`class_name EnemyIdleState`).
* `scripts/enemy/states/enemy_chase_state.gd`: State AI pengejaran pemain (`class_name EnemyChaseState`).
* `scripts/enemy/states/enemy_attack_state.gd`: State AI serang melee dan cooldown (`class_name EnemyAttackState`).
* `scripts/enemy/states/enemy_hurt_state.gd`: State reaksi stagger dan peluruhan knockback (`class_name EnemyHurtState`).
* `scripts/player/states/player_attack_state.gd`: State serang combo 2-tahap pemain (`class_name PlayerAttackState`).
* `scripts/player/states/player_hurt_state.gd`: State stagger, knockback decay, dan dodge-cancel pemain (`class_name PlayerHurtState`).
* `scripts/world/combat_arena.gd`: Level controller arena tempur turunan `WorldBase` (`class_name CombatArena`).
* `scenes/world/combat_arena.tscn`: Scene arena tempur lengkap dengan boundary, 2 dummy slime, player, dan HUD.
* `assets/enemies/dummy_slime.png`: Tekstur pixel art 32x32 RGBA dummy slime musuh.
* `tests/test_phase_4.gd`: Automated unit test suite untuk fondasi sistem combat.
* `tests/runtime_validation_phase_4.gd`: Multi-frame physics & runtime simulation suite untuk combat real-time.
* `docs/reports/2026-11-06-phase-4-combat-system.md`: Laporan komprehensif implementasi Phase 4.

### B. File Dimodifikasi
* `scripts/components/velocity_component.gd`: Penambahan properti `knockback_velocity`, `knockback_friction`, method `apply_knockback()`, `update_knockback()`, dan integrasi ke `apply_to_body()`.
* `scripts/components/hitbox_component.gd`: Penambahan enum `Faction`, properti `faction`, `knockback_force`, `_hit_targets`, `has_hit_target()`, `notify_hit()`, `reset_hit_targets()`, dan setter `is_active` berbasis `set_deferred`.
* `scripts/components/hurtbox_component.gd`: Penambahan enum `Faction`, properti `faction`, `defense`, kalkulasi damage/defense, perhitungan knockback arah penyerang, visual hit flash red modulate, emisi `show_floating_text`, dan sinkronisasi `health_component.is_invulnerable`.
* `scripts/player/player.gd`: Pendaftaran ke grup `&"player"`, konfigurasi fisik Layer 2 / Mask 17, fallback setup combat nodes, method `trigger_attack()`, dan method `get_facing_direction_8way()`.
* `scripts/player/states/player_idle_state.gd`: Transisi tombol aksi `attack` ke state `attack`.
* `scripts/player/states/player_move_state.gd`: Transisi tombol aksi `attack` ke state `attack`.
* `scripts/ui/touch/touch_controls.gd`: Koneksi interaktif tombol sentuh `%AttackButton` (`trigger_attack()`).
* `scenes/ui/touch_controls.tscn`: Penambahan node UI `%AttackButton` (50x50 px, ikon pedang).
* `scenes/player/player.tscn`: Penambahan layer fisik Layer 2 / Mask 17 pada root node Player.
* `scenes/world/outdoor_test.tscn`: Penambahan `ArenaDoor` dan spawn point `from_arena` terhubung ke arena tempur.
* `docs/decisions/technical-decisions.md`: Penambahan ADR-016 (Collision Matrix & Factions), ADR-017 (Player Combo & Buffering), dan ADR-018 (I-Frames & Knockback Integration).
* `docs/architecture/technical-architecture.md`: Pembaruan arsitektur combat, matriks 8-layer, dan hierarki BaseEnemy.
* `docs/development/roadmap.md`: Pembaruan status Phase 4 menjadi **COMPLETED**.

---

## 7. Verification & Test Execution Results

Pengujian dijalankan pada headless Godot Engine 4.7.2 resmi:

### 7.1 Phase 4 Unit Test Suite (`tests/test_phase_4.gd`)
```text
=======================================================
>>> STARTING PHASE 4 AUTOMATED VALIDATION SUITE <<<
=======================================================
--- 1. Testing Combat Collision Matrix & Layers --- (17 PASS)
--- 2. Testing Damage & Defense Absorption --- (3 PASS)
--- 3. Testing Directional Knockback & Friction Decay --- (7 PASS)
--- 4. Testing I-Frames Authority & Single-Hit Tracking --- (7 PASS)
--- 5. Testing Faction Filtering & Friendly Fire Prevention --- (4 PASS)
--- 6. Testing Player Attack State & 2-Stage Combo System --- (15 PASS)
--- 7. Testing Player Hurt State & Knockback Isolation --- (2 PASS)
--- 8. Testing BaseEnemy Instantiation & Parameters --- (10 PASS)
--- 9. Testing BaseEnemy FSM States & Death Lifecycle --- (19 PASS)
--- 10. Testing Combat Arena Scene & Structure --- (13 PASS)

=======================================================
>>> PHASE 4 VALIDATION SUMMARY <<<
Passed: 97
Failed: 0
=======================================================
[SUCCESS] All Phase 4 combat foundation components validated with 0 errors!
```

### 7.2 Phase 4 Runtime Physics Simulation (`tests/runtime_validation_phase_4.gd`)
```text
=======================================================
>>> STARTING PHASE 4 RUNTIME SIMULATION SUITE <<<
=======================================================
--- 1. Testing Runtime Player Attack vs Enemy Interaction --- (7 PASS)
--- 2. Testing Knockback Obstacle Boundary Collision (Zero Clipping) --- (3 PASS)
--- 3. Testing Runtime 2-Stage Combo Chain & Buffering --- (4 PASS)
--- 4. Testing Runtime Enemy Aggro & Pursuit Behavior --- (2 PASS)
--- 5. Testing Runtime Enemy Attack, Hurt Stagger & Player I-Frames Protection --- (7 PASS)
--- 6. Testing Player Knockback Decay, Normal Velocity Isolation & Obstacle Collision --- (11 PASS)
--- 7. Testing Runtime Enemy Death, Defeat Signal & Node Cleanup --- (4 PASS)
--- 8. Testing World Scene Transitions between Outdoor & Arena --- (9 PASS)

=======================================================
>>> RUNTIME SIMULATION SUMMARY <<<
Passed: 47
Failed: 0
=======================================================
[SUCCESS] All Phase 4 runtime simulations passed with 0 errors!
```

### 7.3 Full Project Regression Summary Across All Phases

| Test Suite | File | Ruang Lingkup | Hasil Sebelum Fix | Hasil Sesudah Fix | Status |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **Phase 1 Foundation** | `tests/test_phase_1.gd` | Core Singletons, FSM, Components, Settings | 45 / 45 PASS | 45 / 45 PASS | 100% PASS |
| **Phase 2 Character** | `tests/test_phase_2.gd` | 8-Dir, Modular Visuals, Camera, Touch Controls | 73 / 73 PASS | 73 / 73 PASS | 100% PASS |
| **Phase 3 World Unit** | `tests/test_phase_3.gd` | Hierarchy, Y-Sort, Interaction, Objects, Doors | 91 / 91 PASS | 91 / 91 PASS | 100% PASS |
| **Phase 3 Runtime** | `tests/runtime_validation_phase_3.gd` | Multi-frame Y-Sort, Info Panel, Scene Transitions | 78 / 78 PASS | 78 / 78 PASS | 100% PASS |
| **Phase 4 Combat Unit** | `tests/test_phase_4.gd` | Collision Matrix, Factions, Combos, Enemy AI | 92 / 92 PASS | 97 / 97 PASS | 100% PASS |
| **Phase 4 Runtime** | `tests/runtime_validation_phase_4.gd` | Real-time Combat Physics, Knockback, Death, Arena | 33 / 33 PASS | 47 / 47 PASS | 100% PASS |
| **TOTAL REGRESI** | **6 Suites** | **Seluruh Fondasi Game Petualang Untidar** | **412 / 412 PASS** | **431 / 431 PASS** | **100% PASS** |

> [!NOTE]
> Pengujian fisik pada perangkat keras Android (real device) tetap dijadwalkan pada **Phase 8: Deployment & Optimization** sesuai roadmap proyek.

---

## 8. Post-Implementation Audit Fix: Knockback Velocity Integration & PlayerHurtState

Menindaklanjuti code review pasca-implementasi Phase 4, dilakukan audit mendalam dan perbaikan terarah terhadap integrasi vektor knockback dan penanganan stagger pemain.

### 8.1 Temuan Audit & Analisis Akar Masalah (Root Causes)
1. **Kebocoran Knockback ke Normal Velocity pada `VelocityComponent`:**
   - *Masalah:* Method `apply_to_body()` sebelumnya menjumlahkan `velocity + knockback_velocity` ke `body.velocity`. Setelah `move_and_slide()` dieksekusi, hasil `body.velocity` langsung disimpan kembali ke `velocity = body.velocity`.
   - *Akar Masalah:* Ketika entitas mengalami tabrakan dengan rintangan atau bergerak selama menerima knockback, sisa momentum knockback terserap permanen ke dalam `velocity` normal karakter, menyebabkan pergerakan drifting yang tidak diinginkan dan potensi akumulasi vektor tak terkendali.
2. **Ketiadaan Integrasi Delta Fisika pada State Pemain:**
   - *Masalah:* State pemain (`PlayerIdleState`, `PlayerMoveState`, `PlayerRollState`, `PlayerAttackState`) memanggil `velocity_component.apply_to_body(player)` tanpa parameter `delta` (default `0.0`).
   - *Akar Masalah:* Akibat `delta == 0.0`, method `update_knockback(delta)` tidak pernah menjalankan friksi peluruhan saat pemain berada di state-state tersebut, sehingga knockback pemain terhenti atau tidak meluruh secara mulus.
3. **Ketiadaan State Stagger Dedikasi pada Pemain (`PlayerHurtState`):**
   - *Masalah:* Pemain yang terkena hit dari musuh tidak memiliki visual/fungsional stagger terdedikasi, berisiko langsung memicu serangan atau roll tanpa transisi yang bersih.

### 8.2 Solusi & Perbaikan yang Diterapkan
1. **Refactoring `VelocityComponent` (`scripts/components/velocity_component.gd`):**
   - Mengisolasi variabel `velocity` (kecepatan gerak sengaja) dan `knockback_velocity` (impuls eksternal).
   - Saat `knockback_velocity != Vector2.ZERO`:
     - `body.velocity = velocity + knockback_velocity`.
     - Mengeksekusi `body.move_and_slide()`.
     - Mengiterasi tabrakan slide via `body.get_slide_collision()` dan memproyeksikan normal tabrakan secara terpisah ke `velocity` dan `knockback_velocity` (`slide(normal)`), sehingga knockback tidak mencemari `velocity`.
   - Saat `knockback_velocity == Vector2.ZERO`:
     - Melakukan assignment standar `velocity = body.velocity`.
   - Menambahkan peluruhan otomatis `update_knockback(delta)` berbasis friksi `800.0 px/s²` dan snapping ke `Vector2.ZERO` bila panjang kuadrat $< 0.01$.
   - Menambahkan guard validasi `@GlobalScope.is_finite(delta)` dan `velocity.is_finite()` untuk mencegah nilai NaN atau tak terhingga.
2. **Integrasi Delta Fisika Konsisten di Seluruh State:**
   - Memperbarui pemanggilan `velocity_component.apply_to_body(player, delta)` di seluruh state pemain (`PlayerIdleState`, `PlayerMoveState`, `PlayerRollState`, `PlayerAttackState`).
   - Memperbarui pemanggilan `velocity_component.apply_to_body(enemy, delta)` di seluruh state musuh (`EnemyIdleState`, `EnemyChaseState`, `EnemyAttackState`).
3. **Implementasi `PlayerHurtState` (`scripts/player/states/player_hurt_state.gd`):**
   - Durasi stagger singkat 0.15s dengan integrasi peluruhan knockback.
   - Membatalkan hitbox serang yang sedang aktif saat terkena pukulan.
   - Mendukung dodge-cancel responsif (pemain dapat langsung melakukan roll darurat untuk menghindar).
   - Kembali secara mulus ke `Move` (jika input arah ditahan) atau `Idle` setelah stagger selesai.
   - Terkoneksi otomatis via `hurtbox_component.hit_received` di `Player.gd`.

### 8.3 Hasil Uji Validasi Pasca-Fix
- Unit test combat bertambah dari 92 $\to$ 97 assertions (100% PASS).
- Runtime simulation suite bertambah dari 33 $\to$ 47 assertions (100% PASS), mencakup 10 kriteria runtime spesifik (knockback direction, frame decay, zero reach, normal velocity isolation, obstacle zero clipping, roll/attack recovery, dan I-frames).
- Total regresi proyek: **431 / 431 assertions PASS (100%)**.

### 8.4 Sisa Technical Debt & Scope Mendatang
1. **Fallback Animasi ModularVisuals:** State serangan dan hurt saat ini menggunakan fallback terarah (`attack_down` dan `hurt_down`) via warning log terkontrol hingga sprite sheet visual directional diselesaikan oleh tim art di fase mendatang.
2. **Pengujian Perangkat Keras Android:** Pengujian performa input sentuh dan frame rate pada perangkat fisik Android tetap dialokasikan pada Phase 8 (Deployment & Optimization).

---

## 9. Conclusion & Next Steps

Seluruh kriteria penerimaan dan arsitektur teknis **Phase 4: Combat System** beserta audit perbaikan knockback velocity integration telah selesai diimplementasikan secara solid, teruji bebas regresi, dan terdokumentasi rapi.

Fondasi combat ini siap untuk dihubungkan dengan **Phase 5: Loot & Progression** (sistem inventaris, drop loot berbobot persentase saat musuh terkalahkan, dan peningkatan status senjata/armor karakter).

