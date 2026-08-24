import { Square } from "#game/square"
import { degreeOf } from "#game/warnsdorff"

const BG = {
  stuck: "bg-board-stuck",
  legal: "bg-board-legal",
  current: "bg-board-current",
  visited: "bg-board-visited",
  dark: "bg-board-dark",
  light: "bg-board-light"
}

export function squareView(game, square) {
  const won = game.won
  const stuck = game.stuck
  const current = !!game.currentSquare && square.equals(game.currentSquare)
  const visited = game.visited(square)
  // Before the first move, every square is a legal opening square - highlighting
  // all 64 would just look like a solid-color board, not a checkerboard, so the
  // legal overlay only kicks in once there's an actual current square to move from.
  const legal = !stuck && game.visitedCount > 0 && game.legalMovesFrom.some(sq => sq.equals(square))
  const legalDegree = legal ? degreeOf(game, square) : null
  const dark = (square.x + square.y) % 2 === 1
  const bgClass = won || stuck ? BG.stuck : legal ? BG.legal : current ? BG.current : visited ? BG.visited : dark ? BG.dark : BG.light
  return { square, won, stuck, current, visited, legal, legalDegree, dark, bgClass }
}

export function boardView(game) {
  return Square.all().map(sq => squareView(game, sq))
}
