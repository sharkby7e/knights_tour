import { Square } from "#game/square"

const BG = {
  stuck: "bg-board-stuck",
  legal: "bg-board-legal",
  current: "bg-board-current",
  visited: "bg-board-visited",
  dark: "bg-board-dark",
  light: "bg-board-light"
}

export function squareView(game, square) {
  const stuck = game.stuck
  const current = !!game.currentSquare && square.equals(game.currentSquare)
  const visited = game.visited(square)
  const legal = !stuck && game.legalMovesFrom.some(sq => sq.equals(square))
  const dark = (square.x + square.y) % 2 === 1
  const bgClass = stuck ? BG.stuck : legal ? BG.legal : current ? BG.current : visited ? BG.visited : dark ? BG.dark : BG.light
  return { square, stuck, current, visited, legal, dark, bgClass }
}

export function boardView(game) {
  return Square.all().map(sq => squareView(game, sq))
}
