// Luma's iCal feed has no CORS headers, so the homepage fetches the next event through here.
import { fetchNextEvent } from "../luma.mjs";

export default async () => {
  try {
    return new Response(JSON.stringify(await fetchNextEvent(new Date())), {
      headers: {
        "content-type": "application/json",
        "netlify-cdn-cache-control": "public, durable, s-maxage=300, stale-while-revalidate=3600",
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 502,
      headers: { "content-type": "application/json" },
    });
  }
};

export const config = { path: "/api/next-event" };
