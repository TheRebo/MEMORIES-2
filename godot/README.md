# MEMORIES - versi Godot 4.7

Port dari versi web (Phaser) ke Godot 4.7 dengan GDScript, disusun seperti proyek yang dibuat
di editor: setiap layar, objek, kejadian, dialog dan bagian HUD adalah scene (`.tscn`) dengan
skrip di sebelahnya, dan tampilannya diatur oleh satu Theme.

## Menjalankan

1. Buka Godot 4.7 (renderer Compatibility sudah diatur di proyek).
2. Pilih **Import**, arahkan ke folder `godot/` ini, lalu buka proyeknya.
3. Pembukaan pertama mengimpor semua gambar dan suara (beberapa detik).
4. Tekan **F5**. Scene utama: `scenes/main/main.tscn`.

## Struktur

| Folder | Isi |
|---|---|
| `autoload/` | `Db` (data), `GameState` (simpanan), `Settings`, `Sfx` |
| `scenes/main/` | `main.tscn`: pengganti layar dengan transisi iris |
| `scenes/menu/`, `scenes/story/`, `scenes/title_card/` | menu utama, prolog/ending, kartu penutup |
| `scenes/rooms/` | **tata letak tiap ruangan** (`living_room.tscn`, `kitchen.tscn`, `bedroom.tscn`): latar, perabot, kotoran, barang, tempat simpan, aktor flashback dan kejadian, semuanya node yang bisa digeser dan diatur di Inspector |
| `scenes/room/` | `room.tscn` (dunia, kamera, cahaya, efek, HUD, kejadian) dan sistem ruangan: alat, tangan, lilin, cutscene |
| `scenes/room/hud/` | `hud.tscn` dan bagiannya: slot alat, baris tugas, kartu kejadian, kartu hasil, panah penunjuk |
| `scenes/world/` | objek ruangan: perabot, kotoran, barang, tempat simpan, benda klik 2x, aktor, lilin, kecoa |
| `scenes/events/` | kejadian: kucing, hujan, mati lampu, angin, kecoa (nilai bawaan di `DEFAULTS` tiap skrip) |
| `scenes/ui/` | `modal.gd`, tombol, efek ketik, bintang; `dialogs/`: konfirmasi, pengaturan, kredit, tutorial, jeda |
| `resources/theme/main_theme.tres` | font, warna label, tombol papan kayu, panel kayu dan kertas (variasi tema) |
| `resources/shaders/` | iris transisi dan efek film saat kenangan |
| `data/` | `rooms.json`, `sprites.json`, `story.json`, `game.json` hasil ekspor dari versi web |
| `assets/` | sprite, cutscene, UI (termasuk bingkai 9-slice di `ui/frames`), font, sfx, musik |
| `tests/` | pemeriksaan otomatis (lihat di bawah) |

Gaya panel diatur lewat `theme_type_variation`, misalnya `WoodFrame`, `PaperNote`, `ToastFrame`,
`AlertFrame`, `ToolSlotActive`, `PrimarySmallButton`. Ubah di Theme, semua layar ikut berubah.

## Mengedit ruangan

Buka `scenes/rooms/<ruangan>.tscn`:

- **Props / Zones**: perabot dan tempat simpan. Kotoran di atas perabot adalah anak node
  perabot itu, jadi ikut bergeser bersamanya. Urutan depan-belakang mengikuti posisi y, juga
  di editor.
- **FloorDirt**: kotoran lantai (`Tool`, `Effort`, `Group` = nama tugas di catatan).
- **Items**: barang yang diseret; `Type` harus sama dengan `Accepts` milik sebuah Zone.
- **Interacts**: benda klik 2x (`Needed`, `After Texture`, `Hide After`).
- **Actors**: tokoh flashback; dialog flashback ada di properti `Flashback` milik node akar.
- **Events**: kejadian ruangan; pengaturannya di `Config` dan halaman tutorialnya di `Tutorial`.

Nama ruangan dan urutannya (untuk menu dan tombol pindah ruangan) masih dibaca dari
`data/rooms.json`.

## Pemeriksaan otomatis (CI)

Workflow `.github/workflows/godot.yml` memasang Godot 4.7.2 di GitHub dan, di setiap push:

1. mengimpor aset,
2. mengompilasi setiap skrip (`tests/check_scripts.gd`),
3. memuat setiap scene (`tests/check_scenes.gd`),
4. memainkan game tanpa layar (`tests/smoke.gd`): menu, prolog, ketiga ruangan dengan semua
   kejadiannya, flashback, ending,
5. merender layar-layar utama di xvfb (`tests/screenshots.gd`).

Gagal jika ada error skrip atau langkah yang tidak tercapai.

## Memperbarui data dari versi web

Ruangan disusun di `tools/rooms` (Python) lalu dihasilkan ke `src/data/rooms/*.ts`. Setelah
mengubah ruangan, cerita atau alat, ekspor ulang JSON untuk Godot dari root repo:

```sh
node_modules/.pnpm/esbuild@*/node_modules/esbuild/bin/esbuild tools/export_godot_data.mts \
  --bundle --platform=node --format=esm --alias:@=./src --outfile=/tmp/export.mjs && node /tmp/export.mjs
```

## Kontrol

- **1-4**: tahan untuk memegang Sapu, Pel, Kain Lap, Kemoceng (atau klik slot sekali agar tetap dipegang).
- **5**: tahan lalu lepas di lantai untuk memasang lilin saat mati lampu.
- **Seret** barang ke tempatnya, **klik 2x** benda seperti vas layu.
- **T** catatan tugas, **Esc** jeda, **roda mouse** zoom.

## Catatan

- Simpanan ada di `user://save.json`, pengaturan di `user://settings.json`.
- Aturan tantangan sama dengan versi web: urutan kerja (sapu dulu baru pel, kemoceng dulu baru
  lap), alat yang salah menyebarkan kotoran, timer dengan target bintang, dan debu yang menumpuk
  lagi.
