import { Square } from "#game/square"
import { tickerView } from "#game/ticker_view"

const BG = {
  current: "bg-board-current",
  dark: "bg-board-dark",
  light: "bg-board-light"
}

function playbackSquareView(tourPlayer, square) {
  const current = !!tourPlayer.current && square.equals(tourPlayer.current)
  const trail = !current && tourPlayer.visited(square)
  const dark = (square.x + square.y) % 2 === 1
  const bgClass = current ? BG.current : dark ? BG.dark : BG.light
  return { square, current, trail, dark, bgClass }
}

export function playbackView(tourPlayer, showPath) {
  const { step, total, current, atStart, atEnd, notations } = tourPlayer
  return {
    squares: Square.all().map(sq => playbackSquareView(tourPlayer, sq)),
    notation: current ? current.notation : "—",
    step,
    total,
    ticker: tickerView(notations, step - 1),
    scrubberValue: step,
    atStart,
    atEnd,
    pathPoints: showPath ? tourPlayer.squares.slice(0, step) : []
  }
}
