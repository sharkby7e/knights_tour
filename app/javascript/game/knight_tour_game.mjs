import { Square } from "./square.mjs"
import { MoveFinder } from "./move_finder.mjs"

export class IllegalMoveError extends Error {}

export class KnightTourGame {
  constructor() { this.moves = [] }

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
    return square
  }

  undo() { this.moves.pop() }

  get visitedCount() { return this.moves.length }
  get won() { return this.visitedCount === 64 }
  get stuck() { return this.visitedCount > 0 && !this.won && this.legalMovesFrom.length === 0 }

  notationPath() { return this.moves.map(sq => sq.notation) }
}
