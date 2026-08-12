import { test } from "node:test"
import assert from "node:assert/strict"
import { Square } from "./square.mjs"

test("fromNotation parses algebraic notation, notation round-trips", () => {
  const square = Square.fromNotation("e4")
  assert.equal(square.x, 5)
  assert.equal(square.y, 4)
  assert.equal(square.notation, "e4")
})

test("throws for out-of-bounds coordinates or malformed notation", () => {
  assert.throws(() => new Square(9, 1), RangeError)
  assert.throws(() => Square.fromNotation("z9"), RangeError)
})

test("equals() compares by coordinates", () => {
  assert.ok(new Square(3, 3).equals(new Square(3, 3)))
  assert.ok(!new Square(3, 3).equals(new Square(4, 3)))
})

test("all() returns 64 unique squares, rank 8 down to rank 1", () => {
  const all = Square.all()
  assert.equal(all.length, 64)
  assert.ok(all[0].equals(new Square(1, 8)))
  assert.ok(all[63].equals(new Square(8, 1)))
})
