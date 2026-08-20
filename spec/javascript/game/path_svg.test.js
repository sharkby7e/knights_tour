import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "#game/square"
import { pathPoints } from "#game/path_svg"

test("pathPoints maps squares to the board's SVG coordinate formula", () => {
  const squares = [ Square.fromNotation("a1"), Square.fromNotation("h8") ]
  assert.equal(pathPoints(squares), "6.25,93.75 93.75,6.25")
})

test("pathPoints returns an empty string for no squares", () => {
  assert.equal(pathPoints([]), "")
})
