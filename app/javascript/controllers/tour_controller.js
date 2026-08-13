import { Controller } from "@hotwired/stimulus"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"

export default class extends Controller {
  static targets = [ "square", "visitedCount", "status", "undoButton", "saveButton", "saveForm" ]

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

  save() {
    // wired in step 8
  }

  render() {
    const state = renderState(this.game)

    state.squares.forEach((view, i) => {
      const el = this.squareTargets[i]
      el.className = `w-10 h-10 sm:w-24 sm:h-24 flex items-center justify-center text-3xl sm:text-5xl border border-gray-400 ${view.bgClass}`
      el.textContent = view.current ? "♞" : ""
    })

    this.visitedCountTarget.textContent = state.visitedCount
    this.statusTarget.textContent = state.status
    this.undoButtonTarget.disabled = state.undoDisabled
    this.saveButtonTarget.disabled = state.saveDisabled
  }
}
