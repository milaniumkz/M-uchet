import { test } from "node:test";
import assert from "node:assert/strict";
import { purchaseCostLayers } from "../src/purchase-stock.js";
test("rounded receipt value remains exact across all whole quantities and minor costs", () => {
  for (let quantity = 1; quantity <= 100; quantity++)
    for (let cost = 0; cost < 250; cost++) {
      const layers = purchaseCostLayers(quantity, cost);
      assert.equal(
        layers.reduce((n, l) => n + l.quantity, 0),
        quantity,
      );
      assert.equal(
        layers.reduce(
          (n, l) => n + BigInt(l.quantity) * BigInt(l.unitCost),
          0n,
        ),
        BigInt(cost),
      );
      assert.ok(layers.length <= 2);
      assert.ok(
        layers.every((l) => l.quantity > 0 && Number.isSafeInteger(l.unitCost)),
      );
    }
});
test("large and zero-cost receipts retain exact units without decimal prices", () => {
  for (const [quantity, cost] of [
    [999999999, 1000000000000],
    [999999999, 0],
    [3, 7],
    [1, 1000000000000],
  ]) {
    const layers = purchaseCostLayers(quantity, cost);
    assert.equal(
      layers.reduce((n, l) => n + BigInt(l.quantity) * BigInt(l.unitCost), 0n),
      BigInt(cost),
    );
  }
  for (const [quantity, cost] of [
    [0, 1],
    [1.5, 2],
    [1, -1],
    [1, Number.MAX_SAFE_INTEGER],
  ])
    assert.throws(() => purchaseCostLayers(quantity, cost));
});
