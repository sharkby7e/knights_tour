import { Square } from "#game/square"
import { IllegalMoveError } from "#game/knight_tour_game"
import { boardView } from "#game/board_view"

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
  const status = statusVariant === "won" ? "You won!" : statusVariant === "stuck" ? "Stuck — no legal moves left" : ""
  return {
    squares: boardView(game),
    visitedCount: game.visitedCount,
    status,
    statusVariant,
    undoDisabled: game.visitedCount === 0
  }
}
