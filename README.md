# MEMORIES

Game naratif pixel-art: setelah tiga belas tahun, MC pulang ke rumah Nenek dan membersihkannya ruangan demi ruangan. Setiap ruangan yang bersih membuka satu kenangan.

Port dari proyek Godot 4 ke **Vite + TypeScript (strict) + Phaser 3**, dikelola dengan **pnpm**.

## Main langsung

**https://therebo.github.io/MEMORIES-2/** (dibangun otomatis oleh `.github/workflows/pages.yml` setiap push ke `main` atau `develop`).

## Menjalankan

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm build      # typecheck + build ke dist/
pnpm preview    # jalankan hasil build
pnpm zip        # dist/ -> release/memories-web.zip untuk itch.io
```

Butuh Node 20+ dan pnpm 10.

### Upload ke itch.io

1. `pnpm build && pnpm zip`
2. Di halaman proyek itch.io pilih *Kind of project: HTML*, upload `release/memories-web.zip`, centang *This file will be played in the browser*.
3. Ukuran viewport: 1280 x 720 (game menyesuaikan diri ke ukuran lain). Aktifkan tombol fullscreen bila mau.

Semua aset dipanggil dengan path relatif (`base: './'` di `vite.config.ts`), jadi build bisa jalan dari sub-folder mana pun.

## Kontrol

| Aksi | Mouse / keyboard | Layar sentuh |
|---|---|---|
| Pegang alat | Tahan `1` Sapu, `2` Pel, `3` Kain Lap, `4` Kemoceng, atau tahan slot alat | Ketuk slot alat (ketuk lagi untuk melepas) |
| Bersihkan | Gosokkan kursor di atas kotoran yang cocok | Geser jari di atas kotoran |
| Rapikan barang | Seret barang ke rak / lemari / wastafel / tempat sampah | Sama |
| Objek "klik 2x" | Klik dua kali (vas layu, bantal, guling, selimut) | Ketuk dua kali |
| Lilin (saat listrik padam) | Tahan `5` atau tahan slot Lilin, lepas di lantai | Tahan slot, lepas di lantai |
| Lihat ruangan | Arahkan kursor ke tepi area kosong, scroll untuk zoom | |
| Catatan tugas | `T` buka/tutup; klik baris tugas untuk menunjukkan lokasinya | Tombol Catatan, ketuk baris tugas |
| Jeda | `Esc` (melepas alat dulu bila sedang dipegang dengan ketukan) | Tombol menu |
| Dialog | Klik / `Enter` / `Spasi` lanjut, `Esc` lewati | Ketuk |

Ketuk-untuk-pegang juga berguna di trackpad. Tahan-tombol tetap bekerja seperti versi Godot.

## Tantangan

- **Urutan kerja**: debu yang menutupi noda harus disapu dulu sebelum nodanya bisa dipel, dan perabot berdebu harus dikemoceng dulu sebelum dilap.
- **Salah alat**: menggosok dengan alat yang salah membuat kotoran sedikit menyebar lagi.
- **Waktu dan bintang**: setiap ruangan punya target waktu untuk 3 bintang (2 bintang sampai 1,5 kali target). Rekor tercepat disimpan.
- **Event lebih sering**: kucing datang dua kali, hujan dua kali, kecoa juga muncul di dapur, angin bertiup dua kali, listrik padam lebih lama dengan lilin cadangan lebih sedikit.
- **Debu menumpuk lagi**: sampai 3 kali per ruangan, debu baru muncul di lantai.
- **Level alat** naik setiap 9 kotoran (sebelumnya 6).

## Struktur

```
public/assets/          semua aset (dipanggil relatif: assets/...)
  sprites/              sprite ruangan, nama URL-safe
  audio/music, sfx/     musik (ogg + mp3 cadangan), SFX wav
  ui/  cutscene/  fonts/
src/
  main.ts               bootstrap Phaser + lapisan UI DOM
  app.ts                transisi scene (fade), lapisan UI
  config.ts             resolusi, kamera, depth band, kunci storage
  core/                 emitter bertipe, GameState (save), Settings, Audio
  data/                 data ruangan (hasil konversi), cerita, alat, manifest sprite
  scenes/               Preload, Menu, Story (prolog/epilog), Room, TitleCard
  room/                 RoomContext, ToolSystem, HandSystem, CandleSystem, RoomCutscene
  systems/              CameraRig, Lighting, Fx, TaskTracker
  events/               RoomEvent + Kucing, Hujan, Mati lampu, Angin, Kecoa
  world/                Thing, Dirt, Item, Zone, Interactable, Actor, Candle, Cockroach
  ui/                   HUD, dialog, menu, pengaturan, tutorial, gaya (CSS)
tools/                  konverter .tscn Godot -> data TS
```

### Alur game

Menu -> Prolog (8 slide) -> Ruang Keluarga -> Dapur -> Kamar -> "Pulang" -> Epilog -> Title card.
Tiap ruangan selesai: efek hangat, kilas balik di dalam peta, lalu tombol pindah ruangan. Progres tersimpan otomatis di `localStorage` setiap ruangan selesai.

### Event ruangan

| Ruangan | Event | Muncul di | Inti |
|---|---|---|---|
| Ruang Keluarga | Kucing | 45% | Barang rapi berserakan lagi |
| Dapur | Hujan | 25% | Genangan baru, perlu dipel |
| Dapur | Listrik padam | 65% | Hanya area berlilin yang bisa dibersihkan; terlalu lama gelap menambah sarang laba-laba |
| Kamar | Angin | 40% | Klik jendela berkali-kali; dibiarkan = barang berhamburan + debu baru |
| Kamar | Kecoa | 5% | Bersih-bersih diblokir sampai kecoa diklik |

Ruangan tidak bisa selesai selama event berjalan. Event bisa muncul lagi setelah jeda.

## Mengubah konten

- **Tata letak ruangan**: ditulis dalam Python di `tools/rooms/` (`living.py`, `kitchen.py`, `bedroom.py`), lalu `python3 tools/rooms/emit.py` menulis `src/data/rooms/*.ts`. Pratinjau persis seperti di game: `python3 tools/rooms/compose.py tools/rooms/out_kitchen.json pratinjau.png --boxes`. Lihat `tools/rooms/README.md`.
- **Tingkat kesulitan**: semua effort kotoran dihitung dari satu tabel (`BASE`, `PER_PX`, `DIFFICULTY`) di `tools/rooms/emit.py`; target bintang di `STAR_PAR` (`src/config.ts`).
- **Prolog, epilog, tutorial, kredit**: `src/data/story.ts`.
- **Kredit**: masih `[NAMA]`, isi sesuai tim.
- **Sprite baru**: taruh PNG di `public/assets/sprites/` (atau tambahkan ke `tools/ingest_assets.py` agar otomatis di-trim), lalu `python3 tools/gen_sprites.py` untuk memperbarui `src/data/sprites.ts`.

## Pemetaan aset

- Sprite ruangan: dari proyek Godot (posisinya sudah dikalibrasi tim di editor).
- Objek yang di Godot masih kotak placeholder kini memakai sprite tim sendiri: sampah (`Item Map`), baju dan barang meja (`Item Kamar Tidur`), tong sampah dengan 3 tahap isi (`Item Global`), nakas/tanaman/keranjang (`aset_potongan`), cermin dan bingkai.
- Audio: folder Drive **`audio`** (diprioritaskan). Suara meong dan lilin diambil dari `BGM & SFX` karena tidak ada di `audio`.
- Ilustrasi prolog/epilog: folder Drive `Cutscene`; makam berbunga dirender dari file Aseprite di folder yang sama.
- Font: Yoster Island (codeman38) dan Cairopixel (GGBotNet, SIL OFL 1.1). Lisensi ada di `public/assets/fonts/`.

## Pengujian

Tambahkan `?debug` ke URL untuk membuka `window.__room` (dipakai skrip uji otomatis), misalnya `__room.debugFinish(0)` menyelesaikan semua tugas ruangan.

## Branching

- `main`: rilis.
- `develop`: integrasi.
- `feat/*`, `fix/*`, `chore/*`: satu topik per branch, digabung ke `develop` dengan `--no-ff`, lalu `develop` ke `main` lewat pull request.
