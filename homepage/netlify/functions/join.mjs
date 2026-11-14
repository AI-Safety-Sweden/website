// The signup form at /join posts here. The submission is forwarded as JSON to the Lamdera app
// that stores it, with a shared secret so the Lamdera app only accepts submissions from here.
//
// Netlify environment variables:
//   SIGNUP_FORWARD_URL  the Lamdera endpoint, https://ai-safety-sweden.lamdera.app/_r/signup
//   SIGNUP_SECRET       a long random string, the same as signupSecret in the Lamdera app (AI-Safety-Sweden/admin-site)
//
// The JSON sent is:
//   { "secret": "...", "submittedAt": "2026-11-14T13:00:00.000Z", "answers": { "first_name": "Ada", "areas": ["interp", "other"], ... } }
// Checkbox questions (areas, initiatives, contrib_types) are always lists, everything else is a string.
// Questions the person didn't answer, or that weren't shown to them, are left out.

const multipleChoice = new Set(["areas", "initiatives", "contrib_types"]);

const redirect = (location) => new Response(null, { status: 303, headers: { location } });

const errorPage = (status) =>
  new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Something went wrong | AI Safety Sweden</title>
<body style="font-family: system-ui, sans-serif; max-width: 600px; margin: 64px auto; padding: 0 20px; line-height: 1.6">
<h1>Something went wrong</h1>
<p>Your signup couldn't be saved. Please go back and try again in a moment.</p>
<p><a href="/join">Back to the form</a></p>`,
    { status, headers: { "content-type": "text/html; charset=utf-8" } },
  );

export default async (request) => {
  if (request.method !== "POST") {
    return redirect("/join");
  }

  const form = await request.formData();

  if ((form.get("website") ?? "") !== "") {
    return redirect("/join/thanks");
  }

  if (form.get("privacy") !== "accepted" || (form.get("email") ?? "") === "") {
    return errorPage(400);
  }

  const answers = {};
  for (const [name, value] of form.entries()) {
    if (name === "website" || typeof value !== "string" || value.trim() === "") {
      continue;
    }
    if (multipleChoice.has(name)) {
      (answers[name] ??= []).push(value);
    } else {
      answers[name] = value.trim();
    }
  }

  const url = Netlify.env.get("SIGNUP_FORWARD_URL");
  const secret = Netlify.env.get("SIGNUP_SECRET");
  if (!url || !secret) {
    console.error("SIGNUP_FORWARD_URL or SIGNUP_SECRET isn't set");
    return errorPage(500);
  }

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ secret, submittedAt: new Date().toISOString(), answers }),
    });
    if (!response.ok) {
      console.error(`Lamdera app answered ${response.status}: ${await response.text()}`);
      return errorPage(502);
    }
  } catch (error) {
    console.error("Couldn't reach the Lamdera app", error);
    return errorPage(502);
  }

  return redirect("/join/thanks");
};

export const config = { path: "/api/join" };
