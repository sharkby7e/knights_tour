import { Square } from "#game/square"

const BG = {
  stuck: "bg-zinc-700",
  legal: "bg-emerald-400",
  current: "bg-[#e0cf9c]",
  visited: "bg-red-400",
  dark: "bg-slate-500",
  light: "bg-slate-100"
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
