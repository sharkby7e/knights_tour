import { MoveFinder } from "#game/move_finder"

export function degreeOf(game, square) {
  return new MoveFinder(square).legalMoves().filter(sq => !game.visited(sq)).length
}
