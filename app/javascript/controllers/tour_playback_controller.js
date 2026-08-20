import { Controller } from "@hotwired/stimulus"
import { Square } from "#game/square"
import { TourPlayer } from "#game/tour_player"
import { playbackView } from "#game/playback_view"
import { KNIGHT_SVG } from "#game/knight_svg"
import { renderTicker } from "#game/ticker_dom"
import { renderPath } from "#game/path_svg"

export default class extends Controller {
  static targets = [
    "square", "pathSvg", "stepNum", "stepTotal",
    "startButton", "prevButton", "playButton", "playIcon", "pauseIcon", "nextButton", "endButton",
    "tickerWindow", "tickerTrack", "speedButton", "pathToggle"
  ]
  static values = { moves: Array }

  connect() {
    const squares = this.movesValue.map(n => Square.fromNotation(n))
    this.player = new TourPlayer(squares, squares.length)
    this.showPath = true
    this.speedMs = 450
    this.playing = false
    this.render()
  }

  disconnect() {
    this.stop()
  }

  toStart() { this.stop(); this.goTo(1) }
  prev() { this.stop(); this.goTo(Math.max(1, this.player.step - 1)) }
  next() { this.stop(); this.goTo(this.player.step + 1) }
  toEnd() { this.stop(); this.goTo(this.player.total) }

  seek(index) {
    this.stop()
    this.goTo(index + 1)
  }

  togglePlay() {
    this.playing ? this.stop() : this.play()
  }

  play() {
    if (this.player.atEnd) this.player.goTo(1)
    this.playing = true
    clearInterval(this.timer)
    this.timer = setInterval(() => {
      if (this.player.atEnd) { this.stop(); return }
      this.goTo(this.player.step + 1)
    }, this.speedMs)
    this.render()
  }

  stop() {
    this.playing = false
    clearInterval(this.timer)
    this.render()
  }

  setSpeed(event) {
    this.speedMs = Number(event.currentTarget.dataset.ms)
    this.speedButtonTargets.forEach(b => b.classList.toggle("active", b === event.currentTarget))
    if (this.playing) this.play()
  }

  togglePath() {
    this.showPath = !this.showPath
    this.pathToggleTarget.classList.toggle("on", this.showPath)
    this.pathToggleTarget.setAttribute("aria-pressed", String(this.showPath))
    this.render()
  }

  keydown(event) {
    if (event.key === "ArrowRight") { this.stop(); this.goTo(this.player.step + 1) }
    else if (event.key === "ArrowLeft") { this.stop(); this.goTo(Math.max(1, this.player.step - 1)) }
    else if (event.key === " ") { event.preventDefault(); this.togglePlay() }
  }

  goTo(n) {
    this.player.goTo(n)
    this.render()
  }

  render() {
    const view = playbackView(this.player, this.showPath)

    view.squares.forEach((sq, i) => {
      const el = this.squareTargets[i]
      el.className = `flex items-center justify-center border border-gray-500 transition-colors duration-200 ease-out ${sq.bgClass}`
      el.innerHTML = sq.current ? KNIGHT_SVG : ""
    })

    this.stepNumTarget.textContent = view.step
    this.stepTotalTarget.textContent = view.total

    const atFirstMove = this.player.step <= 1
    this.startButtonTarget.disabled = atFirstMove
    this.prevButtonTarget.disabled = atFirstMove
    this.nextButtonTarget.disabled = view.atEnd
    this.endButtonTarget.disabled = view.atEnd

    this.playIconTarget.classList.toggle("hidden", this.playing)
    this.pauseIconTarget.classList.toggle("hidden", !this.playing)

    renderTicker(this.tickerTrackTarget, this.tickerWindowTarget, view.ticker, i => this.seek(i))
    renderPath(this.pathSvgTarget, view.pathPoints)
  }
}
