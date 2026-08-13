const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"]

export class Square {
  constructor(x, y) {
    if (!Number.isInteger(x) || x < 1 || x > 8) throw new RangeError(`x out of bounds: ${x}`)
    if (!Number.isInteger(y) || y < 1 || y > 8) throw new RangeError(`y out of bounds: ${y}`)
    this.x = x
    this.y = y
    Object.freeze(this)
  }

  static fromNotation(notation) {
    const match = /^([a-h])([1-8])$/.exec(String(notation))
    if (!match) throw new RangeError(`invalid square: ${notation}`)
    return new Square(FILES.indexOf(match[1]) + 1, Number(match[2]))
  }

  static all() {
    if (!Square._all) {
      const squares = []
      for (let y = 8; y >= 1; y--) for (let x = 1; x <= 8; x++) squares.push(new Square(x, y))
      Square._all = squares
    }
    return Square._all
  }

  get notation() { return `${FILES[this.x - 1]}${this.y}` }
  get domId() { return `square_${this.notation}` }
  equals(other) { return other instanceof Square && this.x === other.x && this.y === other.y }
}
