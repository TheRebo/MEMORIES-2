"""Dapur, 512x352 on the new 'Kamar & Dapur' background (no door in the wall)."""
import json, os
from dsl import Room, info

old = json.load(open(os.path.join(os.path.dirname(__file__), 'base_kitchen.json')))
R = Room(old, size={'w': 512, 'h': 352}, background='bg_kamar_dapur')
C, D = 'cloth', 'duster'
pad = lambda t: info(t)[1] - info(t)[2][3]

# ---------------- cooking wall (left): hood, counter with vegetables, stove ----------------
R.prop('Cerobong', 'dapur_cerobong_asap', 64, 82, 'Cerobong', dirt=[(C, 'Lap cerobong', 0.15, 0.05, 0.7, 0.25)])
R.prop('MejaMasak', 'dapur_doc_trim', 64, 112, 'Meja Masak', shadow=True, dirt=[
    (C, 'Lap meja masak', 0.04, 0.3, 0.44, 0.3), (C, 'Lap meja masak', 0.52, 0.3, 0.44, 0.3)])
R.prop('Kompor', 'dapur_doc_1_trim', 64, 94, 'Kompor', z=1, dirt=[(C, 'Lap kompor', 1, 1, 12, 11)])
R.prop('BawangGantung', 'bawang_gantung', 112, 62, 'Bawang')
R.prop('TongAir', 'tong_kayu_1', 22, 132, 'Tong', shadow=True)

# ---------------- sink under the window, pans on the rail ----------------
R.prop('Jendela', 'dapur_jendela_dapur', 160, 52, 'Jendela', dirt=[(C, 'Lap jendela', 3, 3, 0.45, 0.8), (C, 'Lap jendela', 0.52, 3, 0.45, 0.8)])
R.zone('Wastafel', 160, 104, dirt=[(C, 'Lap wastafel', 3, 0.55, 0.88, 0.35)])
R.new_zone('RakDinding', 232, 46, 'Gantungan Alat Masak', 'gantungan_masak_kosong', 'cookware', 3,
           ['gantungan_masak_kosong', 'gantungan_masak_1', 'gantungan_masak_2', 'gantungan_masak_3'],
           dirt=[(C, 'Lap rak dinding', 2, 1, 50, 8)], shadow=False)
R.prop('HerbalGantung', 'herbal_gantung', 284, 54, 'Daun Herbal')

# ---------------- pantry corner (right): cupboard, rack, sacks, fridge ----------------
R.prop('RakSayur', 'rak_kosong_besar', 330, 108, 'Rak Dapur', shadow=True, dirt=[
    (C, 'Lap rak dapur', 3, 6, 0.85, 0.3), (D, 'Kemoceng debu atas furniture', 0, -3, 46, 6)])
R.prop('KendiRak', 'kendi', 318, 80, 'Kendi', z=1)
R.prop('MangkukRak', 'mangkuk_merah', 340, 82, 'Mangkuk', z=1)
R.prop('KarungRak', 'karung_kecil_2', 330, 100, 'Karung', z=1)
R.zone('LemariDapur', 378, 110, dirt=[(C, 'Lap lemari dapur', 2, 4, 0.85, 0.8), (D, 'Kemoceng debu atas furniture', 0, -3, 30, 5)])
R.prop('Kulkas', 'dapur_kulkas', 440, 126, 'Kulkas', shadow=True, scale=(0.8, 0.8), dirt=[
    (C, 'Lap kulkas (dalam & luar)', 0.08, 0.05, 0.84, 0.38), (C, 'Lap kulkas (dalam & luar)', 0.08, 0.5, 0.84, 0.42)])
R.prop('Karung1', 'karung_besar', 412, 134, 'Karung', shadow=True)
R.prop('Karung2', 'karung_kecil_1', 398, 136, 'Karung', shadow=True)
R.prop('RakPendek', 'rak_kosong_pendek', 486, 186, 'Rak', shadow=True, dirt=[(D, 'Kemoceng debu atas furniture', 0, -3, 42, 5)])

# ---------------- dining table on the rug ----------------
R.prop('Karpet', 'karpet_dapur', 256, 236, 'Karpet', layer='ground', base=False, scale=(1.15, 1.15))
R.prop('MejaMakan', 'meja_makan_set', 256, 272, 'Meja Makan', shadow=True, scale=(1.6, 1.6), dirt=[
    (C, 'Lap meja makan', 0.12, 0.28, 0.76, 0.3), (C, 'Lap kursi', 0.36, 0.0, 0.28, 0.18), (C, 'Lap kursi', 0.36, 0.8, 0.28, 0.18),
    (C, 'Lap kursi', 0.0, 0.42, 0.18, 0.28), (C, 'Lap kursi', 0.82, 0.42, 0.18, 0.28)])

# ---------------- prep table (left floor) ----------------
R.prop('MejaSiap', 'pot_meja_kotak', 104, 214, 'Meja Siap', shadow=True, dirt=[(C, 'Lap meja masak', 2, 2, 0.84, 0.4)])
R.prop('Mangkuk', 'mangkuk_merah', 98, 194, 'Mangkuk', z=1)
R.prop('Roti', 'roti_bulat', 112, 194, 'Roti', z=1)
R.prop('Tanaman', 'pot_tanaman_mangkuk', 28, 300, 'Tanaman', shadow=True, scale=(1.3, 1.3), dirt=[(C, 'Lap tanaman', 2, 2, 0.8, 0.6)])
R.prop('Tong2', 'tong_kayu_2', 486, 300, 'Tong', shadow=True)
R.prop('PetiDapur', 'peti_besar_2', 160, 336, 'Peti', shadow=True)
R.zone('TempatSampah', 470, 338)

# ---------------- dishes, cookware, spices, trash ----------------
R.item('Piring1', 228, 252); R.item('Piring2', 256, 254); R.item('Piring3', 284, 252)
R.item('Piring4', 120, 290); R.item('Piring5', 384, 280)
R.item('Alat1', 46, 260); R.item('Alat2', 420, 230); R.item('Alat3', 330, 326)
R.item('Bumbu1', 220, 326); R.item('Bumbu2', 440, 188); R.item('Bumbu3', 60, 170)
R.item('Sampah1', 360, 200); R.item('Sampah2', 150, 160); R.item('Sampah3', 300, 160)
R.item('Sampah4', 90, 330, label='Sampah', tex='sampah_kaleng_2', type='trash', trash=True, group='Buang sampah')

R.actor('Nenek', 66, 132); R.actor('MCKecil', 236, 214); R.actor('MCDewasa', 256, 312)

dust = lambda i, x, y, **e: R.floor(f'SapuLantai{i}', x, y, 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16, **e)
sticky = lambda i, x, y, t: R.floor(f'PelLengket{i}', x, y, 'mop', 'Pel lantai lengket', t, 30, 14)
web = lambda i, x, y, t='jaringlabalaba_sudut', **e: R.floor(f'Jaring{i}', x, y, 'duster', 'Kemoceng jaring laba-laba', t, 32, 32, **e)
for i, (x, y) in enumerate([(130, 140), (230, 150), (330, 150), (460, 220), (60, 230), (180, 300), (300, 316), (400, 316), (360, 236), (150, 250)], 1):
    dust(i, x, y)
tex = ['kamar_ground_pelnoda1', 'kamar_ground_pelnoda2', 'kamar_ground_pelnoda3', 'kamar_ground_pelnoda4']
for i, (x, y) in enumerate([(70, 150), (160, 128), (200, 190), (320, 196), (420, 270), (100, 270), (240, 330), (360, 136)], 1):
    sticky(i, x, y, tex[i % 4])
web(1, 12, 12); web(2, 500, 12, rotation=1.5708); web(3, 340, 14, 'jaring_laba_laba_pro_maxx_by_faris_better_than_punya_zulfa'); web(4, 210, 12)

# events sized for the bigger room
for e in R.d['events']:
    if e['kind'] == 'rain':
        e.update({'spawnArea': {'x': 40, 'y': 130, 'w': 430, 'h': 190}, 'triggerProgress': 20, 'puddleCount': 6, 'maxRepeats': 2, 'repeatInterval': 75})
    if e['kind'] == 'blackout':
        e.update({'triggerProgress': 60, 'blackoutDuration': 75, 'emergencyCandles': 3,
                  'hintPosition': {'x': 256, 'y': 220}, 'cobwebArea': {'x': 10, 'y': 8, 'w': 492, 'h': 44}})
# Cockroaches in the kitchen too (the bedroom tutorial explains them).
roach = json.load(open(os.path.join(os.path.dirname(__file__), 'base_bedroom.json')))['events'][1]
R.d['events'].append({**roach, 'triggerProgress': 42, 'roachCount': 2, 'roachSpeed': 50, 'maxRepeats': 2, 'repeatInterval': 40,
                      'repeatJitter': 8, 'walkArea': {'x': 40, 'y': 130, 'w': 430, 'h': 190}, 'spawnPoint': {'x': 300, 'y': 300}})
for i, ch in {0: {'focus': [90, 120]}, 1: {'moves': [{'actor': 'mc_kecil', 'x': 100, 'y': 136}]},
              3: {'moves': [{'actor': 'mc_kecil', 'x': 236, 'y': 300}], 'focus': [256, 250]}, 4: {'focus': [256, 270]}}.items():
    R.d['flashback'][i].update(ch)
# Dust lying on some stains: these have to be swept before they can be mopped.
_n = len([d for d in R.d['floorDirt'] if d['tool'] == 'broom'])
for k, st in enumerate([d for d in R.d['floorDirt'] if d['tool'] == 'mop' and int(d['id'][-1]) in [2, 4, 6, 8]], 1):
    R.floor(f'SapuLantai{_n + k}', st['x'], st['y'], 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16)
R.save(os.path.join(os.path.dirname(__file__), 'out_kitchen.json'))
