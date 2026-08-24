import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { KnightTourGame } from "#game/knight_tour_game"
import { degreeOf } from "#game/warnsdorff"

test("degreeOf counts a square's own legal knight-moves when nothing is visited yet", () => {
  const game = new KnightTourGame()
  assert.equal(degreeOf(game, Square.fromNotation("d4")), 8)
  assert.equal(degreeOf(game, Square.fromNotation("a1")), 2)
})

test("degreeOf drops as a candidate's onward squares get visited", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  assert.equal(degreeOf(game, Square.fromNotation("c2")), 5)

  game.visit(Square.fromNotation("b3"))
  game.visit(Square.fromNotation("d4"))
  assert.equal(degreeOf(game, Square.fromNotation("c2")), 4)
})
