# MEMORIES - versi Godot 4.7

Port dari versi web (Phaser) ke Godot 4.7 dengan GDScript. Isi game, aturan main dan tata letak
ruangan sama persis karena datanya diekspor langsung dari kode web.

## Menjalankan

1. Buka Godot 4.7 (renderer Compatibility sudah diatur di proyek).
2. Pilih **Import**, arahkan ke folder `godot/` ini, lalu buka proyeknya.
3. Pembukaan pertama mengimpor semua gambar dan suara (beberapa detik).
4. Tekan **F5**.

## Struktur

| Folder | Isi |
|---|---|
| `data/` | `rooms.json`, `sprites.json`, `story.json`, `game.json` hasil ekspor dari web |
| `assets/` | sprite, cutscene, UI, font, sfx (wav) dan musik (ogg) |
| `scripts/autoload/` | `Db` (data), `GameState` (save), `Settings`, `Sfx` |
| `scripts/screens/` | menu, cerita (prolog/ending), ruangan, kartu judul |
| `scripts/room/` | objek dunia (Thing, Dirt, Item, Zone, Interactable, Actor), kamera, cahaya, efek, alat, tangan, lilin, cutscene, HUD |
| `scripts/events/` | kejadian ruangan: kucing, hujan, mati lampu, angin, kecoa |
| `scripts/ui/` | gaya UI, dialog (pengaturan, kredit, tutorial, jeda), efek ketik |

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
