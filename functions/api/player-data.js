// Pages Function: /api/player-data
// Routes all requests (HTTP GET, PUT, and WebSocket upgrades) to the PartyState Durable Object
// Binding: PARTY_STATE (Durable Object namespace, configured in Pages dashboard)

// --- KV IMPLEMENTATION (commented out, kept for reference) ---
// Binding: FG_DATA (KV namespace)
//
// export async function onRequestGet(context) {
//   const data = await context.env.FG_DATA.get("player-data", { type: "json" });
//   if (!data) {
//     return new Response(JSON.stringify({}), {
//       headers: { "Content-Type": "application/json" },
//     });
//   }
//   return new Response(JSON.stringify(data), {
//     headers: { "Content-Type": "application/json" },
//   });
// }
//
// export async function onRequestPut(context) {
//   try {
//     const body = await context.request.text();
//     JSON.parse(body);
//     await context.env.FG_DATA.put("player-data", body);
//     return new Response(JSON.stringify({ success: true, timestamp: new Date().toISOString() }), {
//       headers: { "Content-Type": "application/json" },
//     });
//   } catch (err) {
//     return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
//       status: 400,
//       headers: { "Content-Type": "application/json" },
//     });
//   }
// }

// --- DURABLE OBJECTS IMPLEMENTATION (with WebSocket support) ---

function getStub(env) {
  const id = env.PARTY_STATE.idFromName("default");
  return env.PARTY_STATE.get(id);
}

// Catch-all: forwards GET, PUT, and WebSocket upgrades to the DO
export async function onRequest(context) {
  const stub = getStub(context.env);
  return stub.fetch(context.request);
}
