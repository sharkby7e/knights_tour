import { Square } from "#game/square"
import { MoveFinder } from "#game/move_finder"

export class IllegalMoveError extends Error {}

export class KnightTourGame {
  constructor() {
    this.moves = []
    this.redoStack = []
  }

  get currentSquare() { return this.moves.length ? this.moves[this.moves.length - 1] : null }
  get lastMove() { return this.currentSquare }

  visited(square) { return this.moves.some(m => m.equals(square)) }

  get legalMovesFrom() {
    if (this.moves.length === 0) return Square.all()
    return new MoveFinder(this.currentSquare).legalMoves().filter(sq => !this.visited(sq))
  }

  visit(square) {
    if (!this.legalMovesFrom.some(sq => sq.equals(square))) throw new IllegalMoveError(`${square.notation} is not legal`)
    this.moves.push(square)
    this.redoStack = []
    return square
  }

  prev() { if (this.moves.length > 0) this.redoStack.push(this.moves.pop()) }
  next() { if (this.redoStack.length > 0) this.moves.push(this.redoStack.pop()) }
  toStart() { while (!this.atStart) this.prev() }
  toEnd() { while (!this.atEnd) this.next() }

  goTo(n) {
    const clamped = Math.max(0, Math.min(n, this.moves.length + this.redoStack.length))
    while (this.moves.length > clamped) this.prev()
    while (this.moves.length < clamped) this.next()
  }

  get atStart() { return this.moves.length === 0 }
  get atEnd() { return this.redoStack.length === 0 }

  get visitedCount() { return this.moves.length }
  get won() { return this.visitedCount === 64 }
  get stuck() { return this.visitedCount > 0 && !this.won && this.legalMovesFrom.length === 0 }

  notationPath() { return this.moves.map(sq => sq.notation) }
  fullNotationPath() { return [ ...this.moves, ...this.redoStack.slice().reverse() ].map(sq => sq.notation) }
}
