export class TourPlayer {
  constructor(squares, step = 0) {
    this.squares = squares
    this.total = squares.length
    this.step = 0
    this.goTo(step)
  }

  get current() { return this.step > 0 ? this.squares[this.step - 1] : null }
  get atStart() { return this.step === 0 }
  get atEnd() { return this.step === this.total }
  get notations() { return this.squares.map(sq => sq.notation) }

  visited(square) {
    return this.squares.slice(0, this.step).some(sq => sq.equals(square))
  }

  goTo(n) {
    this.step = Math.max(0, Math.min(this.total, n))
    return this.step
  }
}
