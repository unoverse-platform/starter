/**
 * RestaurantCard — onStart lifecycle handler.
 *
 * Runs SERVER-SIDE when a RestaurantCard instance is created (mcpServer render path). It
 * looks the restaurant up on Google Maps by the card's title and returns the live details;
 * the returned object is merged into THIS instance and streamed to the client.
 *
 * The Google call lives right here — self-contained. The API KEY does NOT: it comes from
 * server config via `ctx.env(...)`. Never hardcode a secret in this file — the rx folder
 * is a shared design folder.
 *
 * ctx (the bounded sandbox):
 *   ctx.props       — this instance's current data (title, tagline, …)
 *   ctx.instanceId  — this card's instance id
 *   ctx.env(name)   — read a server-side config value (e.g. an API key)
 *
 * Return: a partial-props object. Keys hydrate the card BY NAME (unknown keys are inert).
 * NOTE: we deliberately do NOT return `primaryImage` — the card's curated hero is left
 * untouched. Google photos come in ADDITIVELY as the `images` selection.
 */
export default async function onStart(ctx) {
  const title = ctx.props.title;
  if (!title) return {};

  const key = ctx.env("SEARCHAPI_KEY");
  if (!key) return {};

  // Bias the lookup to the venue's region so a global chain (P.F. Chang's, …) resolves to
  // the LOCAL branch, not a random one elsewhere. Region is configurable server-side.
  const region = ctx.env("PLACE_REGION") || "Yas Island, Abu Dhabi";
  const base = "https://www.searchapi.io/api/v1/search";

  const searchUrl =
    `${base}?engine=google_maps&q=${encodeURIComponent(`${title} ${region}`)}&api_key=${key}`;
  const sRes = await fetch(searchUrl, { headers: { Accept: "application/json" } });
  if (!sRes.ok) return {};
  const place = ((await sRes.json()).local_results || [])[0];
  if (!place) return {};

  const out = {
    rating: typeof place.rating === "number" ? place.rating : undefined,
    reviews: typeof place.reviews === "number" ? place.reviews : undefined,
    openState: place.open_state,
    hours: place.hours,
    address: place.address,
    contactPhone: place.phone,
    website: place.website,
  };

  // A small SELECTION of the place's photos (place-details endpoint), upsized from Google's
  // tiny thumbnail size. Additive — never touches the card's own hero image. Photos are a
  // nice-to-have, so a failure here never fails the rest of the handler.
  if (place.place_id) {
    try {
      const pUrl =
        `${base}?engine=google_maps_place&place_id=${encodeURIComponent(place.place_id)}&api_key=${key}`;
      const pRes = await fetch(pUrl, { headers: { Accept: "application/json" } });
      if (pRes.ok) {
        const imgs = ((await pRes.json()).place_result || {}).images || [];
        const images = imgs
          .filter((i) => i && i.thumbnail)
          .slice(0, 4)
          .map((i) => ({ url: i.thumbnail.replace(/=w\d+-h\d+/, "=w400-h300") }));
        if (images.length) out.images = images;
      }
    } catch {
      // ignore — keep the text fields even if photos fail
    }
  }

  return out;
}
