import { Controller } from "@hotwired/stimulus"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"

// lichess.org's "cardinal" piece set (lichess-org/lila on GitHub, open
// source), inlined so it scales with the square via CSS. A bolder, more
// filled silhouette than the classic Wikipedia line-art knight - closer to
// a modern flat piece style. Has its own baked-in gradient + drop-shadow.
const KNIGHT_SVG = `
  <svg viewBox="0 0 50 50" class="w-3/4 h-3/4">
    <defs>
      <linearGradient id="knight-fill" x1="-455.39" x2="-419.41" y1="-338.23" y2="-338.23" gradientTransform="matrix(1.0008 0 0 1.0001 462.75 363.26)" gradientUnits="userSpaceOnUse">
        <stop offset="0" stop-color="#3c3c3c"/>
        <stop offset="1"/>
      </linearGradient>
      <filter id="knight-shadow" color-interpolation-filters="sRGB">
        <feFlood flood-color="#000" flood-opacity=".5" result="flood"/>
        <feComposite in="flood" in2="SourceGraphic" operator="in" result="composite1"/>
        <feGaussianBlur in="composite1" result="blur" stdDeviation=".6"/>
        <feOffset dx="1.6" dy="1.4" result="offset"/>
        <feComposite in="SourceGraphic" in2="offset" result="composite2"/>
      </filter>
    </defs>
    <path fill="url(#knight-fill)" stroke="#e6e6e6" stroke-width="1.1" filter="url(#knight-shadow)"
          d="M18.47 30.29c2.1-1.2 3.33-1.19 5.47-2.2.22 7.42-9.9 7.45-8.1 15.36h26.43s3.1-32.27-16.79-33.63c0 0-1.92-3.6-3.93-3.25 0 0-1.06.84-.46 3.21l-2.3.75s-3.22-2.08-4.13-1.27c-.86.37 1.1 3.28 1.88 3.98-.8 1.15-8.55 12.11-8.97 15.69-.26 2.27 2.03 3.51 3.72 4.12a11.91 11.91 0 0 0 1.74.47c1.42-.26 3.34-2.04 5.45-3.24z"/>
    <path fill="none" stroke="#e6e6e6" stroke-linecap="round" stroke-width="1.1" d="M23.94 28.09s4.43-1.87 4.22-5.84"/>
    <path stroke="#e6e6e6" stroke-linecap="round" stroke-width="1.4" d="M19.1 18.47s.6-1.84 3.46-2.3"/>
    <ellipse cx="21.03" cy="18" fill="#e6e6e6" paint-order="markers fill stroke" rx="1.24" ry="1.17"/>
    <path fill="#fff" stroke="#e6e6e6" stroke-linecap="round" stroke-width="1.4" d="M9.17 29.24s.25-.68.92-1.12"/>
    <path fill="#fff" stroke="#e6e6e6" stroke-linecap="round" stroke-width="1.2" d="M11.64 32.28c.69-.88 1.58-1.32 2.38-1.95"/>
    <path fill="none" stroke="#e6e6e6" stroke-linejoin="round" stroke-width="1.4" d="M30.8 14.87c4.31 2.64 8.47 9.25 8.12 26.08"/>
  </svg>
`.trim()

export default class extends Controller {
  static targets = [ "square", "visitedCount", "status", "undoButton" ]

  connect() {
    this.game = new KnightTourGame()
    this.render()
  }

  move(event) {
    if (attemptMove(this.game, event.currentTarget.dataset.squareNotation)) this.render()
  }

  undo() {
    this.game.undo()
    this.render()
  }

  restart() {
    this.game = new KnightTourGame()
    this.render()
  }

  render() {
    const state = renderState(this.game)

    state.squares.forEach((view, i) => {
      const el = this.squareTargets[i]
      const interactive = view.legal ? "cursor-pointer hover:brightness-110 hover:scale-105" : ""
      el.className = `w-10 h-10 sm:w-24 sm:h-24 flex items-center justify-center border border-gray-400 transition-colors duration-200 ease-out ${view.bgClass} ${interactive}`
      el.innerHTML = view.current ? KNIGHT_SVG : ""
    })

    const statusColor = state.statusVariant === "won" ? "text-board-legal" : state.statusVariant === "stuck" ? "text-board-visited" : ""
    this.statusTarget.className = `min-h-14 flex items-center justify-center text-xl ${statusColor}`
    this.visitedCountTarget.textContent = state.visitedCount
    this.statusTarget.textContent = state.status
    this.undoButtonTarget.disabled = state.undoDisabled
  }
}
