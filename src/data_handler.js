// Decoy data handler for the detection lab. Harmless filler.
function transform(records) {
  return records
    .filter((r) => r && r.active)
    .map((r) => ({ id: r.id, name: String(r.name || "").trim() }));
}

module.exports = { transform };
