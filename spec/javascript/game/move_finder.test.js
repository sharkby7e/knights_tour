import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { MoveFinder } from "#game/move_finder"

test("legalMoves finds all 8 L-shaped moves from a central square", () => {
  const moves = new MoveFinder(new Square(4, 4)).legalMoves()
  assert.equal(moves.length, 8)
})

test("legalMoves filters out-of-bounds moves from a corner", () => {
  const moves = new MoveFinder(Square.fromNotation("a1")).legalMoves()
  const notations = moves.map(sq => sq.notation).sort()
  assert.deepEqual(notations, [ "b3", "c2" ])
})
