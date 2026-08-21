import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"
import { KNIGHT_SVG } from "#game/knight_svg"
import { renderTicker } from "#game/ticker_dom"
import { renderPath } from "#game/path_svg"

export default class extends Controller {
  static targets = [
    "square", "status", "saveButton", "tickerWindow", "tickerTrack", "stepNum",
    "pathSvg", "startButton", "prevButton", "nextButton", "endButton", "pathToggle"
  ]

  connect() {
    this.game = new KnightTourGame()
    this.showPath = true
    this.render()
  }

  move(event) {
    if (attemptMove(this.game, event.currentTarget.dataset.squareNotation)) this.render()
  }

  toStart() { this.game.toStart(); this.render() }
  prev() { this.game.prev(); this.render() }
  next() { this.game.next(); this.render() }
  toEnd() { this.game.toEnd(); this.render() }

  seek(index) {
    this.game.goTo(index + 1)
    this.render()
  }

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
    const size = counting ? "text-3xl" : "text-lg lg:text-3xl"
    this.statusTarget.className = `flex flex-col items-center justify-center lg:text-center whitespace-nowrap lg:whitespace-normal overflow-hidden text-zinc-100 ${size}`
    if (state.hint) {
      this.statusTarget.innerHTML = `<span>${state.status}</span><span class="text-sm text-zinc-400 leading-tight">${state.hint}</span>`
    } else {
      this.statusTarget.textContent = state.status
    }

    this.startButtonTarget.disabled = state.atStart
    this.prevButtonTarget.disabled = state.atStart
    this.nextButtonTarget.disabled = state.atEnd
    this.endButtonTarget.disabled = state.atEnd
    this.saveButtonTarget.classList.toggle("hidden", !state.saveVisible)
    this.stepNumTarget.textContent = this.game.visitedCount

    renderTicker(this.tickerTrackTarget, this.tickerWindowTarget, state.ticker, i => this.seek(i))
    renderPath(this.pathSvgTarget, this.showPath ? this.game.moves : [])
  }
}
