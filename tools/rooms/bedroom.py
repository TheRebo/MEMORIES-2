"""Kamar Nenek dan MC, 512x352 on the new 'Kamar & Dapur' background."""
import json, os
from dsl import Room, info

old = json.load(open(os.path.join(os.path.dirname(__file__), 'base_bedroom.json')))
R = Room(old, size={'w': 512, 'h': 352}, background='bg_kamar_dapur')
C, D = 'cloth', 'duster'
pad = lambda t: info(t)[1] - info(t)[2][3]
oldp = {p['id']: p for p in old['props']}

# ---------------- wall: window (wind event), photos, mirror ----------------
R.prop('Jendela', 'dapur_jendela_dapur', 132, 56, 'Jendela', dirt=[(C, 'Lap jendela', 3, 3, 0.45, 0.8), (C, 'Lap jendela', 0.52, 3, 0.45, 0.8)])
R.prop('FotoBingkai', 'doc_4_trim', 62, 58, 'Foto Bingkai', dirt=[(C, 'Lap foto bingkai', 3, 3, 0.8, 0.8)])
R.prop('LukisanBunga', 'lukisan_bunga', 204, 50, 'Lukisan', dirt=[(C, 'Lap foto bingkai', 3, 3, 0.82, 0.82)])
R.prop('Cermin', 'kamar_doc_trim', 262, 56, 'Cermin', dirt=[(C, 'Lap cermin', 2, 2, 0.84, 0.86)])
R.prop('Jam', 'jam', 300, 30, 'Jam', dirt=[(C, 'Lap jam', 2, 2, 11, 11)])

# ---------------- bed with nightstands (pillow/bolster/blanket keep their old offsets) ----------------
bed = oldp['Kasur']
R.prop('Kasur', 'kamar_ksur_fix', bed['x'], bed['y'], 'Kasur', shadow=True, scale=tuple(bed['scale']), dirt=[
    (D, 'Kemoceng kelambu kasur', 0.08, 0.0, 0.84, 0.1), (C, 'Lap rangka kasur', 0.02, 0.84, 0.96, 0.14)])
R.prop('NightstandL', 'pot_laci_kecil', 66, 100, 'Meja Nakas', shadow=True, dirt=[(C, 'Lap meja nakas', 1, 1, 11, 8)])
R.prop('NightstandR', 'pot_laci_kecil', 194, 100, 'Meja Nakas', shadow=True, dirt=[(C, 'Lap meja nakas', 1, 1, 11, 8)])
R.prop('VasNakas', 'vas_lavender_2', 194, 82, 'Vas', z=1, scale=(0.8, 0.8))
R.inter('Bantal', 112, 110); R.inter('Guling', 150, 112); R.inter('Selimut', 130, 135)
R.prop('Bangku', 'sofa_anglebelakang', 130, 206, 'Bangku', shadow=True, dirt=[(C, 'Lap bangku', 0.1, 2, 0.8, 0.5)])

# ---------------- study corner: desk, chair, shelf, lamp ----------------
R.zone('RakMeja', 336, 74, dirt=[(C, 'Lap rak meja', 2, 4, 0.85, 0.35)])
R.prop('MejaBelajar', 'kamar_meja_belajar', 336, 168, 'Meja Belajar', shadow=True, dirt=[(C, 'Lap meja belajar', 0.36, 0.28, 0.3, 0.1)])
R.prop('KursiBelajar', 'pot_kursi_depan_2', 336, 144, 'Kursi Belajar', shadow=True, dirt=[(C, 'Lap kursi belajar', 1, 1, 10, 9)])
R.prop('LampuBelajar', 'lampu_berdiri', 388, 108, 'Lampu', shadow=True, scale=(0.85, 0.85), dirt=[(C, 'Lap lampu', 2, 2, 0.8, 0.3)])
R.prop('RakBukuKamar', 'rak_buku_isi', 296, 106, 'Rak Buku', shadow=True, dirt=[(D, 'Kemoceng debu atas furniture', 0, -3, 26, 5)])

# ---------------- wardrobe (grime uses the team's 'lemari kotor' art) ----------------
R.zone('Lemari', 470, 114, dirt=[
    ('cloth', 'Bersihkan lemari (dalam & luar)', 0, 4, 0.5, 0.86, {'tex': 'lemari_kotor_1'}),
    ('cloth', 'Bersihkan lemari (dalam & luar)', 0.5, 4, 0.5, 0.86, {'tex': 'lemari_kotor_2'}),
    (D, 'Kemoceng debu atas furniture', 0, -3, 44, 6)])
R.prop('Peti', 'pot_peti_kayu_kecil_1', 432, 112, 'Peti', shadow=True)

# ---------------- floor: rug, old TV corner, basket, plants ----------------
R.prop('Karpet', 'karpet_merah_persegi', 250, 262, 'Karpet', layer='ground', base=False, scale=(1.7, 1.1))
R.prop('KursiSantai', 'sofa_tunggal_biru', 470, 236, 'Kursi Santai', shadow=True, dirt=[(C, 'Lap kursi', 2, 4, 0.8, 0.5)])
R.prop('TVTua', 'tv_hadap_kiri', 430, 268, 'TV Tua', shadow=True, scale=(0.8, 0.8), dirt=[(C, 'Lap TV tua', 0.12, 0.2, 0.7, 0.4)])
R.prop('Keranjang', 'pot_peti_kayu_kecil_1', 60, 286, 'Keranjang', shadow=True, dirt=[(C, 'Lap keranjang', 1, 1, 11, 10)])
R.prop('KarpetKecil', 'karpet_merah_panjang', 96, 316, 'Karpet', layer='ground', base=False)
R.prop('Tanaman', 'pot_tanaman_bunga_putih', 28, 330, 'Tanaman', shadow=True, scale=(1.3, 1.3), dirt=[(C, 'Lap tanaman', 2, 2, 0.8, 0.6)])
R.prop('Vas2', 'vas_pink', 486, 336, 'Vas', shadow=True)
R.zone('TempatSampah', 452, 338)

R.item('BarangMeja1', 280, 300); R.item('BarangMeja2', 180, 314); R.item('BarangMeja3', 400, 196)
R.item('Baju1', 90, 250); R.item('Baju2', 250, 296); R.item('Baju3', 370, 250)
R.item('Sampah1', 210, 330); R.item('Sampah2', 60, 200); R.item('Sampah3', 400, 316)
R.item('Sampah4', 300, 220, label='Sampah', tex='sampah_kaleng_2', type='trash', trash=True, group='Buang sampah')
R.actor('Nenek', 132, 172); R.actor('MCKecil', 96, 178)

dust = lambda i, x, y: R.floor(f'SapuLantai{i}', x, y, 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16)
stain = lambda i, x, y, t: R.floor(f'PelNoda{i}', x, y, 'mop', 'Pel noda lantai', t, 30, 14)
web = lambda i, x, y, t='jaringlabalaba_sudut', **e: R.floor(f'Jaring{i}', x, y, 'duster', 'Kemoceng jaring laba-laba', t, 32, 32, **e)
for i, (x, y) in enumerate([(70, 226), (220, 170), (300, 200), (420, 170), (160, 270), (330, 286), (120, 330), (250, 330), (380, 330), (470, 290)], 1):
    dust(i, x, y)
tex = ['kamar_ground_pelnoda1', 'kamar_ground_pelnoda2', 'kamar_ground_pelnoda3', 'kamar_ground_pelnoda4']
for i, (x, y) in enumerate([(200, 236), (300, 256), (100, 296), (420, 300), (240, 120), (380, 220)], 1):
    stain(i, x, y, tex[i % 4])
web(1, 12, 12); web(2, 500, 12, rotation=1.5708); web(3, 170, 14, 'jaring_laba_laba_pro_maxx_by_faris_better_than_punya_zulfa'); web(4, 410, 12); web(5, 290, 12)

for e in R.d['events']:
    if e['kind'] == 'wind':
        # The window fights back harder and the gust comes twice.
        e.update({'floorArea': {'x': 40, 'y': 130, 'w': 430, 'h': 190}, 'triggerProgress': 35, 'scatterBase': 3, 'clickGain': 0.06,
                  'decayPerSecond': 0.15, 'maxRepeats': 1, 'repeatInterval': 90})
    if e['kind'] == 'cockroach':
        e.update({'walkArea': {'x': 40, 'y': 120, 'w': 430, 'h': 200}, 'spawnPoint': {'x': 250, 'y': 300},
                  'roachCount': 2, 'roachSpeed': 50, 'maxRepeats': 4, 'repeatInterval': 26})
# Dust lying on some stains: these have to be swept before they can be mopped.
_n = len([d for d in R.d['floorDirt'] if d['tool'] == 'broom'])
for k, st in enumerate([d for d in R.d['floorDirt'] if d['tool'] == 'mop' and int(d['id'][-1]) in [1, 3, 5]], 1):
    R.floor(f'SapuLantai{_n + k}', st['x'], st['y'], 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16)
R.save(os.path.join(os.path.dirname(__file__), 'out_bedroom.json'))
