// Pages Function: /api/player-data
// KV key: "player-data" — written by players via browser, never touched by PS script
// Contains: journal, graveyard, quests, playerNotes, companions, assets,
//           partyName, adventureStatus, adventureDate, adventureLocation,
//           adventureArt, houseRules, silverMoonPhase, weirdMoonPhase

export async function onRequestGet(context) {
  const data = await context.env.FG_DATA.get("player-data", { type: "json" });

  if (!data) {
    return new Response(JSON.stringify({}), {
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
}

// PUT - Browser pushes player-editable fields here
export async function onRequestPut(context) {
  try {
    const body = await context.request.text();
    JSON.parse(body);
    await context.env.FG_DATA.put("player-data", body);

    return new Response(JSON.stringify({ success: true, timestamp: new Date().toISOString() }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
}
