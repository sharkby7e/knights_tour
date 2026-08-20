import { test } from "node:test"
import assert from "node:assert/strict"
import { tickerView } from "#game/ticker_view"

test("marks the tile at currentIndex as current", () => {
  const tiles = tickerView([ "a1", "b3", "c5" ], 1)
  assert.deepEqual(tiles.map(t => t.current), [ false, true, false ])
  assert.equal(tiles[1].notation, "b3")
})

test("no tile marked current when index is -1", () => {
  const tiles = tickerView([ "a1", "b3" ], -1)
  assert.ok(tiles.every(t => !t.current))
})
