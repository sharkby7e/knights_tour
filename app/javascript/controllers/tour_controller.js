import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"
import { KNIGHT_SVG } from "#game/knight_svg"
import { renderPath } from "#game/path_svg"

export default class extends Controller {
  static targets = [
    "square", "status", "saveButton", "pathSvg", "prevButton", "pathToggle", "controlLabel",
    "saveDialog", "nameInput", "saveError", "moveCountToggle", "hintDialog"
  ]

  connect() {
    this.game = new KnightTourGame()
    this.showPath = true
    this.showMoveCounts = false
    this.render()

    this.saveDialogTarget.addEventListener("close", () => this.unlockScroll())
    this.hintDialogTarget.addEventListener("close", () => this.unlockScroll())
  }

  lockScroll() {
    this.scrollY = window.scrollY
    document.body.style.position = "fixed"
    document.body.style.top = `-${this.scrollY}px`
    document.body.style.width = "100%"
  }

  unlockScroll() {
    document.body.style.position = ""
    document.body.style.top = ""
    document.body.style.width = ""
    window.scrollTo(0, this.scrollY || 0)
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

  toggleMoveCounts() {
    this.showMoveCounts = !this.showMoveCounts
    this.moveCountToggleTarget.classList.toggle("on", this.showMoveCounts)
    this.moveCountToggleTarget.setAttribute("aria-pressed", String(this.showMoveCounts))
    this.render()
  }

  openHintInfo() {
    this.lockScroll()
    this.hintDialogTarget.showModal()
  }

  closeHintInfo() {
    this.hintDialogTarget.close()
  }

  restart() {
    this.game = new KnightTourGame()
    this.render()
  }

  save() {
    this.saveErrorTarget.classList.add("hidden")
    this.nameInputTarget.value = ""
    this.lockScroll()
    this.saveDialogTarget.showModal()
  }

  cancelSave() {
    this.saveDialogTarget.close()
  }

  async confirmSave(event) {
    event.preventDefault()

    const response = await fetch("/tours", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ moves: this.game.notationPath(), name: this.nameInputTarget.value })
    })

    if (!response.ok) {
      this.saveErrorTarget.classList.remove("hidden")
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

      if (view.current) {
        el.innerHTML = KNIGHT_SVG
      } else if (this.showMoveCounts && view.legal) {
        el.innerHTML = `<span class="text-2xl lg:text-4xl font-bold text-zinc-900/40">${view.legalDegree}</span>`
      } else {
        el.innerHTML = ""
      }
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
