import { Square } from "#game/square"
import { IllegalMoveError } from "#game/knight_tour_game"
import { boardView } from "#game/board_view"
import { tickerView } from "#game/ticker_view"

export function attemptMove(game, notation) {
  try {
    game.visit(Square.fromNotation(notation))
    return true
  } catch (e) {
    if (e instanceof IllegalMoveError) return false
    throw e
  }
}

export function renderState(game) {
  const statusVariant = game.won ? "won" : game.stuck ? "stuck" : null
  const status = statusVariant === "won" ? "You won!" : game.visitedCount === 0 ? "Choose a starting square" : `${game.visitedCount}`
  const hint = statusVariant === "stuck" ? "Restart or save" : ""
  return {
    squares: boardView(game),
    status,
    statusVariant,
    hint,
    atStart: game.atStart,
    atEnd: game.atEnd,
    saveVisible: statusVariant === "won" || statusVariant === "stuck",
    ticker: tickerView(game.fullNotationPath(), game.moves.length - 1)
  }
}
