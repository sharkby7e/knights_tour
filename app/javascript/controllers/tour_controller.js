import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"
import { KNIGHT_SVG } from "#game/knight_svg"
import { renderPath } from "#game/path_svg"

export default class extends Controller {
  static targets = [
    "square", "status", "saveButton", "pathSvg", "prevButton", "pathToggle", "controlLabel"
  ]

  connect() {
    this.game = new KnightTourGame()
    this.showPath = true
    this.render()
  }

  move(event) {
    if (attemptMove(this.game, event.currentTarget.dataset.squareNotation)) this.render()
  }

  prev() { this.game.prev(); this.render() }
  next() { this.game.next(); this.render() }

  keydown(event) {
    if (event.key === "ArrowRight") this.next()
    else if (event.key === "ArrowLeft") this.prev()
  }

  togglePath() {
    this.showPath = !this.showPath
    this.pathToggleTarget.classList.toggle("on", this.showPath)
    this.pathToggleTarget.setAttribute("aria-pressed", String(this.showPath))
    this.render()
  }

  restart() {
    this.game = new KnightTourGame()
    this.render()
  }

  async save() {
    const response = await fetch("/tours", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ moves: this.game.notationPath() })
    })

    if (!response.ok) {
      this.statusTarget.textContent = "Couldn't save — try again."
      return
    }

    const { redirect_url } = await response.json()
    Turbo.visit(redirect_url)
  }

  render() {
    const state = renderState(this.game)

    state.squares.forEach((view, i) => {
      const el = this.squareTargets[i]
      const interactive = view.legal ? "cursor-pointer hover:brightness-110 hover:scale-105" : ""
      const landing = view.current ? "animate-pop" : ""
      el.className = `flex items-center justify-center border border-gray-500 transition-colors duration-200 ease-out ${view.bgClass} ${interactive} ${landing}`
      el.innerHTML = view.current ? KNIGHT_SVG : ""
    })

    const counting = state.statusVariant !== "won" && this.game.visitedCount > 0
    const size = counting ? "text-3xl lg:text-6xl" : "text-lg lg:text-2xl"
    this.statusTarget.className = `lg:text-center whitespace-nowrap lg:whitespace-normal overflow-hidden text-zinc-100 ${size}`
    this.statusTarget.textContent = state.status

    this.prevButtonTarget.disabled = state.atStart
    this.saveButtonTarget.disabled = state.atStart

    const showLabels = state.atStart || state.statusVariant !== null
    this.controlLabelTargets.forEach(el => el.classList.toggle("hidden", !showLabels))

    renderPath(this.pathSvgTarget, this.showPath ? this.game.moves : [])
  }
}
