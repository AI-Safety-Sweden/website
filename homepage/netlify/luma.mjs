// The next event on the AI Safety Sweden Luma calendar, read from its public iCal feed (no API key needed).
// Used by the Netlify function netlify/functions/next-event.mjs and at build time by custom-backend-task.ts.
const icalUrl = "https://api.lu.ma/ics/get?entity=calendar&id=cal-finBJrhLOfffXbS";
const calendarUrl = "https://luma.com/aisafetysweden";

export async function fetchNextEvent(now) {
  const response = await fetch(icalUrl);
  if (!response.ok) {
    throw new Error(`Luma iCal feed answered ${response.status}`);
  }
  const events = parseEvents(await response.text())
    .filter((event) => event.status !== "CANCELLED" && event.end > now)
    .sort((a, b) => a.start - b.start);
  if (events.length === 0) {
    return null;
  }
  const event = events[0];
  return {
    title: event.title,
    start: stockholmTime(event.start),
    end: stockholmTime(event.end),
    url: event.url,
    location: event.location,
  };
}

function parseEvents(ical) {
  const lines = ical.replace(/\r?\n[ \t]/g, "").split(/\r?\n/);
  const events = [];
  let current = null;
  for (const line of lines) {
    if (line === "BEGIN:VEVENT") {
      current = {};
    } else if (line === "END:VEVENT") {
      if (current !== null) {
        events.push(current);
      }
      current = null;
    } else if (current !== null) {
      const colon = line.indexOf(":");
      if (colon !== -1) {
        current[line.slice(0, colon).split(";")[0]] = line.slice(colon + 1);
      }
    }
  }
  return events
    .filter((event) => event.DTSTART && event.DTEND && event.SUMMARY)
    .map((event) => {
      const description = unescapeText(event.DESCRIPTION || "");
      // Luma's own events link to their page in the description. Events added to the calendar from
      // elsewhere (e.g. Meetup) only link to the calendar there, and put their own page in LOCATION.
      const link = (description.match(/https:\/\/luma\.com\/[\w-]+/g) || []).find(
        (url) => url !== calendarUrl
      );
      const location = unescapeText(event.LOCATION || "").replace(/, Sweden$/, "");
      const locationIsUrl = /^https?:\/\//.test(location);
      return {
        title: unescapeText(event.SUMMARY),
        start: parseDate(event.DTSTART),
        end: parseDate(event.DTEND),
        status: event.STATUS || "",
        url:
          link ??
          (locationIsUrl ? location : `https://luma.com/event/${(event.UID || "").split("@")[0]}`),
        location: location === "" || locationIsUrl ? null : location,
      };
    });
}

function unescapeText(text) {
  return text.replace(/\\([\;,nN])/g, (_, c) => (c === "n" || c === "N" ? "\n" : c));
}

// Luma writes times in UTC, e.g. 20261120T173000Z.
function parseDate(text) {
  const m = text.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/);
  if (!m) {
    throw new Error(`Unexpected iCal date ${text}`);
  }
  return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]));
}

// Formats a date as Stockholm local time, e.g. "2026-11-20T18:30".
function stockholmTime(date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: "Europe/Stockholm",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value])
  );
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}
