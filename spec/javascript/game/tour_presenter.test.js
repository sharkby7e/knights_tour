import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { KnightTourGame } from "#game/knight_tour_game"
import { attemptMove, renderState } from "#game/tour_presenter"

test("attemptMove records a legal move and returns true", () => {
  const game = new KnightTourGame()
  assert.ok(attemptMove(game, "a1"))
  assert.equal(game.visitedCount, 1)
})

test("attemptMove leaves the game untouched and returns false for an illegal move", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  assert.ok(!attemptMove(game, "h8"))
  assert.equal(game.visitedCount, 1)
})

test("renderState reports atStart/atEnd with no moves, reports 64 squares, and prompts for a starting square", () => {
  const game = new KnightTourGame()
  const state = renderState(game)
  assert.equal(state.squares.length, 64)
  assert.ok(state.atStart)
  assert.ok(state.atEnd)
  assert.match(state.status, /starting square/i)
})

test("renderState reports atStart false once a move has been made", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  const state = renderState(game)
  assert.equal(state.atStart, false)
})

test("renderState reports atEnd false after stepping back with prev", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  game.prev()
  const state = renderState(game)
  assert.equal(state.atEnd, false)
})

test("renderState hides save with no moves", () => {
  const game = new KnightTourGame()
  const state = renderState(game)
  assert.equal(state.saveVisible, false)
})

test("renderState hides save mid-game", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  const state = renderState(game)
  assert.equal(state.saveVisible, false)
})

test("renderState reports won status and variant once all 64 squares are visited", () => {
  const game = new KnightTourGame()
  game.moves = Square.all()
  const state = renderState(game)
  assert.match(state.status, /won/i)
  assert.equal(state.statusVariant, "won")
})

test("renderState shows save once all 64 squares are visited", () => {
  const game = new KnightTourGame()
  game.moves = Square.all()
  const state = renderState(game)
  assert.equal(state.saveVisible, true)
})

test("renderState reports the move count and stuck variant at a real dead end", () => {
  const game = new KnightTourGame()
  ;[ "c2", "d4", "b3", "a1" ].forEach(n => attemptMove(game, n))
  const state = renderState(game)
  assert.equal(state.status, "4")
  assert.equal(state.statusVariant, "stuck")
  assert.equal(state.atStart, false)
})

test("renderState shows save at a real dead end", () => {
  const game = new KnightTourGame()
  ;[ "c2", "d4", "b3", "a1" ].forEach(n => attemptMove(game, n))
  const state = renderState(game)
  assert.equal(state.saveVisible, true)
})

test("renderState reports no status variant mid-game", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  const state = renderState(game)
  assert.equal(state.statusVariant, null)
})

test("renderState shows the move count mid-game instead of a blank status", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  attemptMove(game, "c2")
  const state = renderState(game)
  assert.equal(state.status, "2")
})

test("renderState includes ticker data reflecting the current moves", () => {
  const game = new KnightTourGame()
  assert.deepEqual(renderState(game).ticker, [])

  attemptMove(game, "a1")
  attemptMove(game, "c2")
  const state = renderState(game)
  assert.deepEqual(state.ticker.map(t => t.notation), [ "a1", "c2" ])
  assert.deepEqual(state.ticker.map(t => t.current), [ false, true ])
})

test("renderState's ticker still includes redo-buffered moves as future tiles after prev", () => {
  const game = new KnightTourGame()
  attemptMove(game, "a1")
  attemptMove(game, "c2")
  game.prev()

  const state = renderState(game)
  assert.deepEqual(state.ticker.map(t => t.notation), [ "a1", "c2" ])
  assert.deepEqual(state.ticker.map(t => t.current), [ true, false ])
})
