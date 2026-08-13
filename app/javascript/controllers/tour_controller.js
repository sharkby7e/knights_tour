import { Controller } from "@hotwired/stimulus"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"

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
      const landing = view.current ? "animate-pop" : ""
      el.className = `w-10 h-10 sm:w-24 sm:h-24 flex items-center justify-center text-3xl sm:text-5xl border border-gray-400 transition-colors duration-200 ease-out ${view.bgClass} ${interactive} ${landing}`
      el.textContent = view.current ? "♞" : ""
    })

    const statusColor = state.statusVariant === "won" ? "text-board-legal" : state.statusVariant === "stuck" ? "text-board-visited" : ""
    this.statusTarget.className = statusColor
    this.visitedCountTarget.textContent = state.visitedCount
    this.statusTarget.textContent = state.status
    this.undoButtonTarget.disabled = state.undoDisabled
  }
}
