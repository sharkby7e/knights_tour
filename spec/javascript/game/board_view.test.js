import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { KnightTourGame } from "#game/knight_tour_game"
import { boardView, squareView } from "#game/board_view"

test("boardView returns all 64 squares", () => {
  const game = new KnightTourGame()
  assert.equal(boardView(game).length, 64)
})

test("legal squares from the current position are highlighted, others aren't", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))

  const c2 = squareView(game, Square.fromNotation("c2"))
  const h8 = squareView(game, Square.fromNotation("h8"))
  assert.equal(c2.bgClass, "bg-board-legal")
  assert.notEqual(h8.bgClass, "bg-board-legal")
})

test("a stuck game colors every square bg-board-stuck, overriding legal/current/visited", () => {
  const game = new KnightTourGame()
  ;[ "c2", "d4", "b3", "a1" ].forEach(n => game.visit(Square.fromNotation(n)))
  assert.ok(game.stuck)

  const views = boardView(game)
  assert.ok(views.every(v => v.bgClass === "bg-board-stuck"))
})

test("the current square is highlighted regardless of checkerboard parity", () => {
  const game = new KnightTourGame()
  game.visit(Square.fromNotation("a1"))

  const view = squareView(game, Square.fromNotation("a1"))
  assert.ok(view.current)
  assert.equal(view.bgClass, "bg-board-current")
})
