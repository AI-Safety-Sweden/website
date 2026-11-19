// Custom BackendTasks go here. See https://elm-pages.com/docs/backend-task
import { fetchNextEvent } from "./netlify/luma.mjs";

export async function nextEvent() {
  return fetchNextEvent(new Date());
}
