import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "./square.mjs"
import { KnightTourGame, IllegalMoveError } from "./knight_tour_game.mjs"

test("first move can be any square; visit records it and advances currentSquare", () => {
  const game = new KnightTourGame()
  assert.deepEqual(game.legalMovesFrom, Square.all())

  game.visit(Square.fromNotation("a1"))
  assert.ok(game.currentSquare.equals(Square.fromNotation("a1")))
  assert.equal(game.visitedCount, 1)
})

test("visit throws IllegalMoveError for a non-legal square, without recording it", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))

  assert.throws(() => game.visit(Square.fromNotation("h8")), IllegalMoveError)
  assert.equal(game.visitedCount, 1)
})

test("undo removes the last move and reverts currentSquare", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  game.visit(Square.fromNotation("b3"))

  game.undo()
  assert.ok(game.currentSquare.equals(Square.fromNotation("a1")))
  assert.equal(game.visitedCount, 1)
})

test("won is true once all 64 squares are visited", () => {
  const game = new KnightTourGame()
  game.moves = Square.all()
  assert.ok(game.won)
})

test("stuck is true at a real dead end (c2 -> d4 -> b3 -> a1)", () => {
  const game = new KnightTourGame()
  ;[ "c2", "d4", "b3", "a1" ].forEach(n => game.visit(Square.fromNotation(n)))
  assert.ok(game.stuck)
})
