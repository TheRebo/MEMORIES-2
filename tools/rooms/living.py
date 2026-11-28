"""Ruang Keluarga, 512x352. Back wall ends at y=64; floor x 16..496, y 64..336; door in the wall at x~323."""
import json, os
from dsl import Room, info

old = json.load(open(os.path.join(os.path.dirname(__file__), 'base_living_room.json')))
R = Room(old)
C, D = 'cloth', 'duster'


def pad(tex):
    """Transparent rows under the art, so 'feet' land where the art ends."""
    w, h, bb = info(tex)
    return h - bb[3]


# ---------------- back wall: hanging things (fully inside y 6..62) ----------------
R.prop('Jendela', 'dapur_jendela_dapur', 120, 56, 'Jendela', dirt=[
    (C, 'Lap jendela', 3, 3, 0.45, 0.8), (C, 'Lap jendela', 0.52, 3, 0.45, 0.8)])
R.prop('Lukisan', 'lukisan_gunung', 186, 50, 'Lukisan', dirt=[(C, 'Lap lukisan & foto', 4, 4, 0.84, 0.75)])
R.prop('JamDinding', 'jam', 236, 32, 'Jam', dirt=[(C, 'Lap jam dinding', 2, 2, 11, 11)])
R.prop('Pintu', 'doc_2', 323, 64, 'Pintu', dirt=[(C, 'Lap pintu', 4, 6, 0.76, 0.8)])
R.prop('FotoKeluarga', 'grandma_grandchild', 378, 44, 'Foto Keluarga', dirt=[(C, 'Lap lukisan & foto', 3, 3, 0.82, 0.75)])
R.prop('FotoWisuda', 'foto_wisuda', 418, 60, 'Foto Wisuda', dirt=[(C, 'Lap lukisan & foto', 3, 4, 0.8, 0.84)])

# ---------------- back wall: standing furniture (feet a little onto the floor) ----------------
R.zone('RakBuku', 40, 100 + pad('buku_teisi_4'), dirt=[
    (C, 'Lap rak buku', 2, 10, 28, 18), (C, 'Lap rak buku', 2, 34, 28, 18), (D, 'Kemoceng debu atas furniture', 0, -3, 32, 6)])
R.prop('LampuKiri', 'lampu_berdiri', 74, 100, 'Lampu', shadow=True, dirt=[(C, 'Lap lampu', 2, 2, 0.8, 0.3)])
R.prop('TVCabinet', 'doc_6', 256, 104, 'TV + Meja TV', shadow=True, dirt=[
    (C, 'Lap TV & meja TV', 0.22, 2, 0.5, 0.42), (C, 'Lap TV & meja TV', 0.08, 0.6, 0.84, 0.3), (D, 'Kemoceng debu atas furniture', 0.25, -3, 0.5, 6)])
R.prop('KesetPintu', 'karpet_merah_kecil', 323, 80, 'Keset', layer='ground', base=False)
R.zone('LemariPajangan', 472, 104, dirt=[
    (C, 'Lap lemari pajangan', 3, 8, 0.4, 0.75), (C, 'Lap lemari pajangan', 0.52, 8, 0.4, 0.75), (D, 'Kemoceng debu atas furniture', 0, -3, 44, 6)])
R.prop('RakSempit', 'rak_sempit', 438, 102, 'Rak Kecil', shadow=True, dirt=[(D, 'Kemoceng debu atas furniture', 0, -3, 16, 5)])
R.prop('Vas1', 'vas_lavender_1', 438, 64, 'Vas', z=1)

# ---------------- sitting group on the carpet, facing the TV ----------------
R.prop('Karpet', 'karpet_toska', 256, 192, 'Karpet', layer='ground', base=False)
R.prop('MejaTamu', 'doc_9', 256, 196, 'Meja Tamu', shadow=True, dirt=[(C, 'Lap meja tamu', 3, 2, 0.88, 0.5)])
R.prop('Sofa', 'sofa_anglebelakang', 256, 248, 'Sofa', shadow=True, dirt=[
    (C, 'Lap sofa', 0.1, 2, 0.26, 0.5), (C, 'Lap sofa', 0.37, 2, 0.26, 0.5), (C, 'Lap sofa', 0.64, 2, 0.26, 0.5)])
R.prop('KursiKiri', 'sofa_anglekekanan', 176, 210, 'Kursi', shadow=True, dirt=[(C, 'Lap kursi', 3, 3, 0.75, 0.6)])
R.prop('KursiKanan', 'sofa_anglekekiri', 336, 210, 'Kursi', shadow=True, dirt=[(C, 'Lap kursi', 0.18, 3, 0.75, 0.6)])

# ---------------- reading corner (left) ----------------
R.prop('KarpetBaca', 'karpet_bulat', 70, 196, 'Karpet Kecil', layer='ground', base=False, scale=(1.6, 1.6))
R.prop('MejaSamping', 'meja_bundar_trim', 70, 204, 'Meja', shadow=True, dirt=[(C, 'Lap meja samping', 4, 2, 0.8, 0.45)])
R.prop('BukuBaca', 'buku_terbuka_2', 64, 186, 'Buku', z=1, scale=(0.6, 0.6))
R.prop('KursiBaca', 'kursi_samping_kanan', 40, 214, 'Kursi', shadow=True)
R.prop('VasMeja', 'vas_pink', 82, 186, 'Vas', z=1, scale=(0.8, 0.8))

# ---------------- right side: armchair, side table, tall display shelf ----------------
R.prop('SofaBiru', 'sofa_tunggal_biru', 478, 222, 'Kursi Santai', shadow=True, dirt=[(C, 'Lap kursi', 2, 4, 0.8, 0.5)])
R.prop('Nakas', 'pot_laci_kecil', 478, 248, 'Laci', shadow=True)
R.prop('LampuKanan', 'lampu_berdiri', 452, 210, 'Lampu', shadow=True, scale=(0.85, 0.85), dirt=[(C, 'Lap lampu', 2, 2, 0.8, 0.3)])

# ---------------- front of the room (bottom): tea table, chest, plants ----------------
R.prop('KarpetTeh', 'karpet_merah_persegi', 404, 304, 'Karpet', layer='ground', base=False, scale=(1.3, 0.8))
R.prop('MejaTeh', 'meja_oval', 404, 310, 'Meja Teh', shadow=True, dirt=[(C, 'Lap meja teh', 4, 3, 0.8, 0.4)])
R.prop('KursiTehKiri', 'kursi_samping_kiri', 374, 314, 'Kursi', shadow=True)
R.prop('KursiTehKanan', 'kursi_samping_kanan', 434, 314, 'Kursi', shadow=True)
R.prop('Kendi', 'kendi', 400, 284, 'Kendi', z=1)
R.prop('PetiKayu', 'peti_besar_1', 150, 336, 'Peti', shadow=True, dirt=[(D, 'Kemoceng debu atas furniture', 0, -2, 19, 5)])
R.prop('Tanaman', 'pot_tanaman_pot', 486, 340, 'Tanaman', shadow=True, scale=(1.4, 1.4), dirt=[(C, 'Lap tanaman', 2, 2, 0.8, 0.7)])
R.prop('Tanaman2', 'pot_tanaman_mangkuk', 26, 132, 'Tanaman', shadow=True, scale=(1.2, 1.2))
R.prop('Tanaman3', 'vas_kuning', 200, 108, 'Vas', shadow=True)
R.zone('TempatSampah', 36, 336)

# ---------------- loose things to tidy ----------------
R.item('Buku1', 120, 292); R.item('Buku2', 300, 300); R.item('Buku3', 210, 278); R.item('Buku4', 470, 160)
R.item('Pajangan1', 60, 272); R.item('Pajangan2', 350, 148); R.item('Pajangan3', 250, 326)
R.item('Sampah1', 196, 320); R.item('Sampah2', 120, 158); R.item('Sampah3', 400, 168)
R.item('Sampah4', 320, 280, label='Sampah', tex='sampah_kaleng_2', type='trash', trash=True, group='Buang sampah')
R.inter('VasBungaLayu', 262, 186 + pad('vas_bunga'), z=1)

# ---------------- cutscene actors ----------------
R.actor('Nenek', 236, 238); R.actor('MCKecil', 270, 242); R.actor('MCDewasa', 323, 92)

# ---------------- floor grime ----------------
dust = lambda i, x, y, **e: R.floor(f'SapuLantai{i}', x, y, 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16, **e)
stain = lambda i, x, y, t: R.floor(f'PelNoda{i}', x, y, 'mop', 'Pel noda lantai', t, 30, 14)
web = lambda i, x, y, t='jaringlabalaba_sudut', **e: R.floor(f'Jaring{i}', x, y, 'duster', 'Kemoceng jaring laba-laba', t, 32, 32, **e)
candle = lambda n: {'reward': {'item': 'candle', 'amount': n, 'message': 'Kamu menemukan sebatang lilin di bawah debu!'}}
for i, (x, y, e) in enumerate([(110, 136, {}), (176, 150, candle(2)), (360, 130, {}), (420, 190, {}), (60, 250, candle(1)),
                                (150, 270, {}), (300, 272, {}), (440, 262, {}), (90, 312, candle(1)), (230, 300, {}),
                                (340, 320, {}), (380, 236, {})], 1):
    dust(i, x, y, **e)
for i, (x, y, t) in enumerate([(130, 230, 'kamar_ground_pelnoda3'), (288, 316, 'kamar_ground_pelnoda1'), (460, 296, 'kamar_ground_pelnoda2'),
                               (100, 270, 'kamar_ground_pelnoda4'), (380, 112, 'kamar_ground_pelnoda1'), (190, 112, 'kamar_ground_pelnoda2')], 1):
    stain(i, x, y, t)
web(1, 12, 12); web(2, 500, 12, rotation=1.5708); web(3, 160, 14, 'jaring_laba_laba_pro_maxx_by_faris_better_than_punya_zulfa'); web(4, 360, 16, 'jaring_laba_laba_pro_maxx_by_faris_better_than_punya_zulfa'); web(5, 280, 12)

# Flashback camera and walks follow the new furniture (photo on the wall, the sofa).
for i, ch in {0: {'moves': [{'actor': 'mc', 'x': 372, 'y': 84}], 'focus': [360, 80]}, 1: {'focus': [378, 36]},
              2: {'focus': [256, 214]}, 5: {'moves': [{'actor': 'mc_kecil', 'x': 292, 'y': 246}]}}.items():
    R.d['flashback'][i].update(ch)
for e in R.d['events']:
    if e['kind'] == 'cat':
        # Earlier, messier, and it comes back once more.
        e.update({'triggerProgress': 35, 'scatterCount': 9, 'minItemsNeeded': 4, 'maxRepeats': 2, 'repeatInterval': 80,
                  'catEntry': {'x': 560, 'y': 220}, 'catExit': {'x': -40, 'y': 280}, 'floorArea': {'x': 40, 'y': 130, 'w': 430, 'h': 190}})
# Dust lying on some stains: these have to be swept before they can be mopped.
_n = len([d for d in R.d['floorDirt'] if d['tool'] == 'broom'])
for k, st in enumerate([d for d in R.d['floorDirt'] if d['tool'] == 'mop' and int(d['id'][-1]) in [1, 3, 5]], 1):
    R.floor(f'SapuLantai{_n + k}', st['x'], st['y'], 'broom', 'Sapu lantai', 'debu_ulahan_daus', 32, 16)
R.save(os.path.join(os.path.dirname(__file__), 'out_living_room.json'))
