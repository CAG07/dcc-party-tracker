// Durable Object class: stores party data with strong consistency
// Deployed as a standalone Worker, bound to the Pages project via dashboard
import { DurableObject } from "cloudflare:workers";

export class PartyState extends DurableObject {
  async fetch(request) {
    const method = request.method;

    if (method === "GET") {
      const data = await this.ctx.storage.get("data");
      return new Response(JSON.stringify(data || {}), {
        headers: { "Content-Type": "application/json" },
      });
    }

    if (method === "PUT") {
      try {
        const body = await request.text();
        const parsed = JSON.parse(body);
        await this.ctx.storage.put("data", parsed);
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
}

// Worker fetch handler (required by Wrangler, not called by Pages)
export default {
  async fetch(request, env) {
    return new Response("This Worker provides Durable Objects for the DCC Party Tracker.", {
      headers: { "Content-Type": "text/plain" },
    });
  },
};
