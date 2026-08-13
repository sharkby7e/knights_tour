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
  const status = game.won ? "You won!" : game.stuck ? "Stuck — no legal moves left" : ""
  return {
    squares: boardView(game),
    visitedCount: game.visitedCount,
    status,
    undoDisabled: game.visitedCount === 0
  }
}
