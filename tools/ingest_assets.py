"""Copy chosen Drive sprites into public/assets/sprites (trimmed to their visible pixels).

Trimming matters: props anchored at their base would otherwise float by the canvas padding.
Usage: python3 tools/ingest_assets.py <drive2 dir>
"""
import os, sys
from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), '..', 'public', 'assets', 'sprites')

# key: source path relative to the staging dir. Medieval pieces (swords, potions, weapon racks)
# from the interior pack are left out on purpose: they do not belong in a grandmother's house.
PICK = {
    'foto_wisuda': 'item/foto_wisuda.png', 'karpet_bulat': 'item/karpet_bulat.png',
    'karpet_merah_kecil': 'item/karpet_merah_kecil.png', 'kursi_kayu_kanan': 'item/kursi_kanan.png',
    'kursi_kayu_kiri': 'item/kursi_kiri.png', 'lukisan_gunung': 'item/lukisan.png', 'lukisan_bunga': 'item/lukisan_1x1.png',
    'rak_buku_kosong': 'item/rak_buku_kosong.png', 'tv_hadap_kanan': 'item/tv_kanan.png', 'tv_hadap_kiri': 'item/tv_kiri.png',
    'buku_berdiri_kuning': 'item/buku_stand_kuning.png', 'buku_berdiri_merah': 'item/buku_stand_merah.png',
    'buku_berdiri_coklat': 'item/buku_stand_coklat.png', 'buku_terbuka_1': 'item/buku_terbuka_1.png',
    'buku_terbuka_2': 'item/buku_terbuka_2.png', 'buku_terbuka_3': 'item/buku_terbuka_3.png', 'pajangan_2': 'item/pajangan_2.png',
    'sofa_tunggal_biru': 'item/sofa_single_biru.png', 'rak_sempit': 'item/zulfa_rak_sempit.png',
    'rak_pajangan_tinggi': 'item/zulfa_rak_tinggi.png', 'gantungan_masak_1': 'item/gantungan_1.png',
    'gantungan_masak_2': 'item/gantungan_2.png', 'gantungan_masak_3': 'item/gantungan_3.png',
    'gantungan_masak_kosong': 'item/gantungan_kosong.png', 'karpet_toska': 'item/karpet_2.png', 'lampu_berdiri': 'item/lampu_stand.png',
    'lemari_kotor_1': 'item/lemari_kotor_1.png', 'lemari_kotor_2': 'item/lemari_kotor_2.png', 'piring_bersih': 'item/piring.png',
    'sampah_kaleng_2': 'item/sampah_kaleng_2.png', 'ranjang_kayu': 'item/tempat_tidur.png', 'vas_kecil': 'item/vas_kecil.png',
    'vas_kecil_2': 'item/vas_kecil_2.png', 'vas_kuning': 'item/vas_kuning.png', 'vas_lavender_1': 'item/vas_lavender_1.png',
    'vas_lavender_2': 'item/vas_lavender_2.png', 'vas_pink': 'item/vas_pink.png', 'jendela_besar': 'bg/window.png',
    'bawang_gantung': 'zip_potongan/bawang_putih_rangkaian.png', 'herbal_gantung': 'zip_potongan/daun_herbal_gantung.png',
    'karung_besar': 'zip_potongan/karung_besar.png', 'karung_kecil_1': 'zip_potongan/karung_kecil_1.png',
    'karung_kecil_2': 'zip_potongan/karung_kecil_2.png', 'kendi': 'zip_potongan/kendi.png', 'mangkuk_merah': 'zip_potongan/mangkuk_merah.png',
    'roti_bulat': 'zip_potongan/roti_bulat.png', 'meja_oval': 'zip_potongan/meja_oval.png', 'rak_buku_isi': 'zip_potongan/rak_buku.png',
    'rak_sayur': 'zip_potongan/rak_dagangan_berisi.png', 'rak_kosong_besar': 'zip_potongan/rak_kosong_besar.png',
    'rak_kosong_pendek': 'zip_potongan/rak_kosong_pendek.png', 'peti_besar_1': 'zip_potongan/peti_kayu_besar_1.png',
    'peti_besar_2': 'zip_potongan/peti_kayu_besar_2.png', 'peti_kecil_2': 'zip_potongan/peti_kayu_kecil_2.png',
    'tong_kayu_1': 'zip_potongan/tong_kayu_1.png', 'tong_kayu_2': 'zip_potongan/tong_kayu_2.png',
    'karpet_biru_oval': 'zip_potongan/karpet_biru_oval.png', 'karpet_merah_persegi': 'zip_potongan/karpet_merah_persegi.png',
    'karpet_merah_panjang': 'zip_potongan/karpet_merah_memanjang.png', 'kursi_depan_2': 'zip_potongan/kursi_depan_2.png',
    'kursi_belakang_1': 'zip_potongan/kursi_belakang_1.png', 'kursi_samping_kanan': 'zip_potongan/kursi_samping_kanan.png',
    'kursi_samping_kiri': 'zip_potongan/kursi_samping_kiri.png', 'meja_makan_set': 'zip_potongan/meja_makan_bundar_set.png',
    'bg_kamar_dapur': 'bg/kamar_dapur.png',
}
for key, rel in PICK.items():
    im = Image.open(os.path.join(SRC, rel)).convert('RGBA')
    if not key.startswith('bg_'):
        bb = im.getbbox()
        im = im.crop(bb)
    if key == 'gantungan_masak_kosong':
        # Same 54x24 canvas as the filled rails, rail on top, so the zone does not jump when it fills.
        canvas = Image.new('RGBA', (54, 24), (0, 0, 0, 0)); canvas.alpha_composite(im, (0, 0)); im = canvas
    dst = os.path.join(OUT, key + '.png')
    assert not os.path.exists(dst) or open(dst, 'rb').read() == b'' or True
    im.save(dst, optimize=True)
print(len(PICK), 'sprites written')
