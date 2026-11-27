/**
 * Suggests landscape on portrait touch screens. Desktop windows and itch.io embeds that happen
 * to be taller than wide are never blocked, and the notice can always be dismissed.
 */
export function initOrientationNotice(): void {
  const el = document.getElementById('rotate');
  const dismiss = document.getElementById('rotate-dismiss');
  if (!el || !dismiss) return;
  const coarse = window.matchMedia('(pointer: coarse)');
  let dismissed = false;
  try {
    dismissed = window.sessionStorage.getItem('memories.rotateDismissed') === '1';
  } catch {
    /* storage blocked: keep in memory only */
  }
  const update = (): void => {
    const portrait = window.innerHeight > window.innerWidth;
    el.hidden = dismissed || !coarse.matches || !portrait;
  };
  dismiss.addEventListener('click', () => {
    dismissed = true;
    try {
      window.sessionStorage.setItem('memories.rotateDismissed', '1');
    } catch {
      /* ignore */
    }
    update();
  });
  window.addEventListener('resize', update);
  window.addEventListener('orientationchange', update);
  coarse.addEventListener?.('change', update);
  update();
}
