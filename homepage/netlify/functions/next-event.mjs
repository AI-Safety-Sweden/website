// Meetup's API doesn't allow browser requests (its CORS preflight rejects the JSON
// content type it requires), so the homepage fetches the next event through here.
const query = `query { groupByUrlname(urlname: "stockholm-ai-safety") { events(first: 1, status: ACTIVE, sort: ASC) { edges { node { title dateTime endTime eventUrl venues { name city } } } } } }`;

export default async () => {
  const response = await fetch("https://api.meetup.com/gql-ext", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query }),
  });
  return new Response(await response.text(), {
    status: response.status,
    headers: {
      "content-type": "application/json",
      "netlify-cdn-cache-control": "public, durable, s-maxage=300, stale-while-revalidate=3600",
    },
  });
};

export const config = { path: "/api/next-event" };
