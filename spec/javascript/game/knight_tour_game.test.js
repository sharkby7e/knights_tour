import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { KnightTourGame, IllegalMoveError } from "#game/knight_tour_game"

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

test("prev removes the last move and reverts currentSquare", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  game.visit(Square.fromNotation("b3"))

  game.prev()
  assert.ok(game.currentSquare.equals(Square.fromNotation("a1")))
  assert.equal(game.visitedCount, 1)
})

test("next restores a move that was stepped back over with prev", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  game.visit(Square.fromNotation("b3"))
  game.prev()

  game.next()
  assert.ok(game.currentSquare.equals(Square.fromNotation("b3")))
  assert.equal(game.visitedCount, 2)
})

test("toStart and toEnd round-trip through the full move history", () => {
  const game = new KnightTourGame()
  ;[ "a1", "b3", "d4" ].forEach(n => game.visit(Square.fromNotation(n)))

  game.toStart()
  assert.equal(game.visitedCount, 0)
  assert.equal(game.currentSquare, null)

  game.toEnd()
  assert.equal(game.visitedCount, 3)
  assert.ok(game.currentSquare.equals(Square.fromNotation("d4")))
})

test("goTo clamps to the valid range in both directions", () => {
  const game = new KnightTourGame()
  ;[ "a1", "b3", "d4" ].forEach(n => game.visit(Square.fromNotation(n)))
  game.toStart()

  game.goTo(-5)
  assert.equal(game.visitedCount, 0)

  game.goTo(2)
  assert.equal(game.visitedCount, 2)

  game.goTo(999)
  assert.equal(game.visitedCount, 3)
})

test("atStart/atEnd reflect both boundaries", () => {
  const game = new KnightTourGame()
  assert.ok(game.atStart)
  assert.ok(game.atEnd)

  game.visit(Square.fromNotation("a1"))
  assert.ok(!game.atStart)
  assert.ok(game.atEnd)

  game.prev()
  assert.ok(game.atStart)
  assert.ok(!game.atEnd)
})

test("fullNotationPath includes played and redo-buffered moves in chronological order", () => {
  const game = new KnightTourGame()
  ;[ "a1", "b3", "d4" ].forEach(n => game.visit(Square.fromNotation(n)))
  game.prev()

  assert.deepEqual(game.fullNotationPath(), [ "a1", "b3", "d4" ])
  assert.deepEqual(game.notationPath(), [ "a1", "b3" ])
})

test("visiting a new square after prev discards the stale redo branch", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  game.visit(Square.fromNotation("b3"))
  game.prev()

  game.visit(Square.fromNotation("c2"))
  assert.deepEqual(game.notationPath(), [ "a1", "c2" ])
  assert.ok(game.atEnd)
})

test("a rejected illegal visit does not clear the redo stack", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))
  game.visit(Square.fromNotation("b3"))
  game.prev()

  assert.throws(() => game.visit(Square.fromNotation("h8")), IllegalMoveError)
  assert.ok(!game.atEnd)
  game.next()
  assert.ok(game.currentSquare.equals(Square.fromNotation("b3")))
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
