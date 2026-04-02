// Durable Object class: stores party data with strong consistency
// Supports WebSocket for real-time sync and HTTP GET/PUT as fallback
import { DurableObject } from "cloudflare:workers";

export class PartyState extends DurableObject {
  async fetch(request) {
    // WebSocket upgrade
    if (request.headers.get("Upgrade") === "websocket") {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server);

      // Send current state to new connection
      const data = await this.ctx.storage.get("data");
      server.send(JSON.stringify(data || {}));

      return new Response(null, { status: 101, webSocket: client });
    }

    // HTTP GET (initial load + fallback poll)
    if (request.method === "GET") {
      const data = await this.ctx.storage.get("data");
      return new Response(JSON.stringify(data || {}), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // HTTP PUT (fallback save + JSON import)
    if (request.method === "PUT") {
      try {
        const body = await request.text();
        const parsed = JSON.parse(body);
        await this.ctx.storage.put("data", parsed);

        // Broadcast to all connected WebSocket clients
        this.ctx.getWebSockets().forEach((ws) => {
          try { ws.send(body); } catch (e) {}
        });

        return new Response(
          JSON.stringify({ success: true, timestamp: new Date().toISOString() }),
          { headers: { "Content-Type": "application/json" } }
        );
      } catch (err) {
        return new Response(
          JSON.stringify({ error: "Invalid JSON payload" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    return new Response("Method not allowed", { status: 405 });
  }

  async webSocketMessage(ws, message) {
    try {
      const parsed = JSON.parse(message);
      await this.ctx.storage.put("data", parsed);

      // Broadcast to all OTHER connected clients
      this.ctx.getWebSockets().forEach((socket) => {
        if (socket !== ws) {
          try { socket.send(message); } catch (e) {}
        }
      });
    } catch (e) {
      // Invalid message, ignore
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    // Hibernation API handles cleanup automatically
  }

  async webSocketError(ws, error) {
    ws.close();
  }
}

// Worker fetch handler (required by Wrangler, not called by Pages)
export default {
  async fetch(request, env) {
    return new Response(
      "This Worker provides Durable Objects for the DCC Party Tracker.",
      { headers: { "Content-Type": "text/plain" } }
    );
  },
};
