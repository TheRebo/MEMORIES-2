import type { SfxKey } from './audio';
import type { TutorialPage } from './types';

/** Full-screen illustrations in public/assets/cutscene/. */
export type CutsceneArt =
  | 'bus_stop'
  | 'trees'
  | 'lobby'
  | 'door_wall'
  | 'door_wall_window'
  | 'hand_empty'
  | 'hand_key'
  | 'hand_cut_fix'
  | 'grave_day'
  | 'grave_dark'
  | 'grave_flowers';

/** Small scripted motion on top of a slide. */
export type SlideMotion = 'busArrive' | 'busLeave' | 'panRight' | 'slowZoom' | 'handRise' | 'none';

export interface Slide {
  readonly art: CutsceneArt;
  readonly motion?: SlideMotion;
  readonly speaker: string;
  readonly text: string;
  /** SFX key played when the slide appears. */
  readonly sfx?: SfxKey;
  /** Seconds before auto-advance; absent = wait for the player. */
  readonly hold?: number;
  /** Darken the art (0..1) to keep text readable or set mood. */
  readonly dim?: number;
  /** Where the text box sits, so it does not cover the subject of the art. */
  readonly box?: 'center' | 'right';
}

/** Prolog, from the Godot intro scene (matches Lore.txt "INTRO - baru"). */
export const INTRO: readonly Slide[] = [
  { art: 'bus_stop', motion: 'busArrive', speaker: 'Narator', sfx: 'room_enter',
    text: 'Sebuah bus berhenti di pemberhentian terakhirnya, di pelosok yang jauh dari hiruk-pikuknya kota.' },
  { art: 'bus_stop', motion: 'busLeave', speaker: 'MC',
    text: 'Huh... Akhirnya sampai juga ya. Sudah lama sekali aku tidak ke sini...' },
  { art: 'trees', motion: 'panRight', speaker: 'MC (batin)',
    text: 'Aku berjalan menuju sebuah rumah, tempat yang sejak awal memang sudah menjadi tujuanku sampai ke pelosok seperti ini.' },
  { art: 'lobby', motion: 'slowZoom', speaker: 'MC', text: 'Ternyata masih utuh ya...' },
  { art: 'lobby', motion: 'slowZoom', speaker: 'MC (batin)',
    text: 'Yap, rumah tempat aku dibesarkan oleh Nenek. Sudah tiga belas tahun sejak aku meninggalkan rumah ini untuk mencari kerja di kota.' },
  { art: 'hand_key', speaker: 'MC', sfx: 'rattle',
    text: 'Kuncinya masih bisa dipakai nggak ya? Kelihatannya sudah berkarat... Oke, bisa!' },
  { art: 'door_wall_window', speaker: 'MC (batin)', sfx: 'unjam',
    text: 'Begitu pintunya terbuka, aku disambut pemandangan yang... seperti kapal pecah. Yah, memang wajar sih.' },
  { art: 'hand_cut_fix', motion: 'handRise', speaker: 'MC', sfx: 'slide_in', text: 'Huh... oke, kita bersihkan dulu!' },
];

/** Epilog, from the Godot ending scene (matches "revisi ending.docx"). */
export const ENDING: readonly Slide[] = [
  { art: 'grave_dark', box: 'right', speaker: 'MC', text: 'Maaf ya nek... aku jadi jarang jengukin nenek...' },
  { art: 'grave_day', box: 'right', speaker: 'MC', text: 'Mulai sekarang aku bakal lebih sering kok.' },
  { art: 'grave_flowers', box: 'right', speaker: 'Narator', sfx: 'ending_chime',
    text: 'Kemudian aku meletakkan bunga di atas makam Nenek, lalu membersihkan sekitarnya.' },
];

/** First-play tutorial (Godot room_systems.tscn > TutorialPopup > Start Pages). */
export const START_TUTORIAL: readonly TutorialPage[] = [
  { title: 'Sapu', image: 'item_sapu',
    text: 'Tahan tombol 1 (atau tahan klik di slot Sapu) untuk memegang Sapu. Gosokkan mouse di atas debu lantai sampai bersih. Lepas tombol untuk melepas alat.' },
  { title: 'Pel', image: 'item_pel',
    text: 'Tahan tombol 2 untuk memegang Pel. Gosok noda, lantai lengket, dan genangan air sampai hilang.' },
  { title: 'Kain Lap', image: 'item_kain_lap',
    text: 'Tahan tombol 3 untuk memegang Kain Lap. Gosok furnitur, jendela, cermin, dan benda lain yang berdebu.' },
  { title: 'Kemoceng', image: 'kemoceng_daus',
    text: 'Tahan tombol 4 untuk memegang Kemoceng. Bersihkan jaring laba-laba dan debu di tempat tinggi seperti sudut atas ruangan dan puncak lemari.' },
  { title: 'Rapikan barang', image: 'buku_biru',
    text: 'Barang kecil di lantai bisa diseret ke rak, lemari, wastafel, atau tempat sampah. Objek berlabel "Klik 2x" (vas layu, bantal, guling, selimut) diklik dua kali dengan cepat.' },
];

export const CREDITS = {
  title: 'MEMORIES',
  // The Godot credits still held "(isi namamu)". Names are left for the team to fill in.
  roles: [
    { role: 'Game Design & Programming', name: '[NAMA]' },
    { role: 'Art', name: '[NAMA]' },
    { role: 'Music & SFX', name: '[NAMA]' },
  ],
  thirdParty: [
    'Font "Yoster Island" oleh codeman38 (zone38.net)',
    'Font "Cairopixel" oleh GGBotNet, SIL Open Font License 1.1',
  ],
  thanks: 'Terima kasih sudah bermain.',
} as const;
