import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { TourPlayer } from "#game/tour_player"

const squares = () => [ "a1", "b3", "c5" ].map(n => Square.fromNotation(n))

test("current and visited reflect the step cursor", () => {
  const player = new TourPlayer(squares(), 2)
  assert.ok(player.current.equals(Square.fromNotation("b3")))
  assert.ok(player.visited(Square.fromNotation("a1")))
  assert.ok(!player.visited(Square.fromNotation("c5")))
})

test("goTo clamps to the valid step range", () => {
  const player = new TourPlayer(squares(), 1)
  player.goTo(-5)
  assert.equal(player.step, 0)
  assert.ok(player.atStart)

  player.goTo(99)
  assert.equal(player.step, 3)
  assert.ok(player.atEnd)
})
