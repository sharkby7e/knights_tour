import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"
import { KNIGHT_SVG } from "#game/knight_svg"

export default class extends Controller {
  static targets = [ "square", "visitedCount", "status", "undoButton", "saveButton" ]

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
      el.className = `w-10 h-10 lg:w-24 lg:h-24 flex items-center justify-center border border-gray-500 transition-colors duration-200 ease-out ${view.bgClass} ${interactive} ${landing}`
      el.innerHTML = view.current ? KNIGHT_SVG : ""
    })

    const statusColor = state.statusVariant === "won" ? "text-board-legal" : state.statusVariant === "stuck" ? "text-board-visited" : ""
    this.statusTarget.className = `h-7 flex items-center justify-center text-xl whitespace-nowrap ${statusColor}`
    this.visitedCountTarget.textContent = state.visitedCount
    this.statusTarget.textContent = state.status
    this.undoButtonTarget.disabled = state.undoDisabled
    this.saveButtonTarget.disabled = state.saveDisabled
  }
}
