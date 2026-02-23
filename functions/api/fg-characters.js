// Pages Function: /api/fg-characters
// KV key: "fg-characters" — written by PS script, read-only for players
// Contains: characters, inactiveCharacters, characterOrder from Fantasy Grounds

export async function onRequestGet(context) {
  const data = await context.env.FG_DATA.get("fg-characters", { type: "json" });

  if (!data) {
    return new Response(JSON.stringify({ error: "No character data uploaded yet" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
}

// PUT - Only the PS script should call this
export async function onRequestPut(context) {
  try {
    const body = await context.request.text();
    JSON.parse(body);
    await context.env.FG_DATA.put("fg-characters", body);

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
