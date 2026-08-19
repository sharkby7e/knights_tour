const TICK_W_REM = 2.5

export function renderTicker(trackEl, windowEl, tiles, onSeek = null) {
  const tag = onSeek ? "button" : "div"
  trackEl.innerHTML = tiles.map((t, i) =>
    `<${tag}${onSeek ? ' type="button"' : ""} class="tick${t.current ? " current" : ""}" data-index="${i}">${t.notation}</${tag}>`
  ).join("")

  if (onSeek) {
    trackEl.querySelectorAll(".tick").forEach(el => {
      el.addEventListener("click", () => onSeek(Number(el.dataset.index)))
    })
  }

  const currentIndex = tiles.findIndex(t => t.current)
  const rootPx = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16
  const tickW = TICK_W_REM * rootPx
  const windowWidth = windowEl.clientWidth
  const centerOn = Math.max(0, currentIndex)
  trackEl.style.transform = `translateX(${windowWidth / 2 - tickW / 2 - centerOn * tickW}px)`
}
