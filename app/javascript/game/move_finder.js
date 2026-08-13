import { Square } from "#game/square"

const MOVE_SET = [ [ 1, 2 ], [ 2, 1 ], [ 2, -1 ], [ 1, -2 ], [ -1, -2 ], [ -2, -1 ], [ -2, 1 ], [ -1, 2 ] ]

export class MoveFinder {
  constructor(square) { this.square = square }

  legalMoves() {
    return this.moveCandidates()
      .filter(([ x, y ]) => x >= 1 && x <= 8 && y >= 1 && y <= 8)
      .map(([ x, y ]) => new Square(x, y))
  }

  moveCandidates() {
    return MOVE_SET.map(([ dx, dy ]) => [ this.square.x + dx, this.square.y + dy ])
  }
}
