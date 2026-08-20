import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { TourPlayer } from "#game/tour_player"
import { playbackView } from "#game/playback_view"

const squares = () => [ "a1", "b3", "c5" ].map(n => Square.fromNotation(n))

test("trail is set on visited-but-not-current squares, not the current or unvisited ones", () => {
  const view = playbackView(new TourPlayer(squares(), 2), true)
  const at = notation => view.squares.find(s => s.square.notation === notation)

  assert.equal(at("a1").trail, true)
  assert.equal(at("b3").current, true)
  assert.equal(at("b3").trail, false)
  assert.equal(at("c5").trail, false)
})

test("atStart/atEnd reflect both boundaries", () => {
  const start = playbackView(new TourPlayer(squares(), 0), true)
  assert.equal(start.atStart, true)
  assert.equal(start.atEnd, false)

  const end = playbackView(new TourPlayer(squares(), 3), true)
  assert.equal(end.atStart, false)
  assert.equal(end.atEnd, true)
})

test("pathPoints is empty when showPath is false", () => {
  const view = playbackView(new TourPlayer(squares(), 2), false)
  assert.deepEqual(view.pathPoints, [])
})
