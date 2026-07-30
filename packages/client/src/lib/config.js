// App configuration — all values come from Vite env vars (VITE_*).
//
// This client knows only a TEMPLATE name + where the server is. It loads
// `unoverse://templates/<name>` and renders it. If that template carries a
// workflow `binding` (the §4b app manifest), the client opens the data-plane and
// the workflow streams live components in; a plain template just renders its own
// welcome/default state. The workflow binding is never hardcoded here.

export const config = {
  // The Unoverse server base — one host serves it all: definitions/theme (`/mcp`),
  // the per-session data-plane (`/stream`), and the REST workflow trigger
  // (`/execute`). (§5/§5b: MCP carries everything structured, one process.)
  serverUrl: import.meta.env.VITE_UNOVERSE_URL || "http://localhost:4105",
  // The REST origin the app fires the workflow at — `{apiUrl}/api/workflows/:id/execute`
  // (§5a/§5b). Defaults to the server (collapsed runtime); override for a split gateway.
  get apiUrl() {
    return import.meta.env.VITE_API_URL || this.serverUrl;
  },
  templateId: import.meta.env.VITE_TEMPLATE_ID || "sab/sabchatlayout",
};

// Demo client registry — each entry is one CHANNEL skin: which template the app loads
// and which "fake page" screenshot sits behind the drawer. Each client is its own PATH
// route (`/sab`, `/bpp`) so the URL alone opens that channel's chat — no launcher, no
// query param. The Unoverse landing page (`/`) links out to each. Template ids MUST be
// fully org-qualified (`<org>/<name>`, e.g. `bpp/bppchatlayout`) — bare names are not relied on.
export const clients = {
  sab: {
    label: "SAB",
    tagline: "Consumer banking channel",
    templateId: config.templateId,
    background: "https://res.cloudinary.com/sonik/image/upload/v1768405848/gravity/sab.png",
  },
  bpp: {
    label: "BPP",
    tagline: "Enterprise portal channel",
    templateId: "bpp/bppchatlayout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1783256770/bppWeb_c9bila.png",
  },
  yas: {
    label: "Yas Island",
    tagline: "Destination experiences channel",
    templateId: "yasisland/yasislandchatlayout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1784377715/yasIsland/yasHome.jpg",
    // No public flag here: whether this channel needs a login is the SERVER's answer
    // (/.well-known/unoverse-app/<org>/<app>), derived from the workflow trigger's
    // auth/public toggle on the canvas.
  },
  yasvoice: {
    label: "Yas Island Voice",
    tagline: "Voice concierge channel",
    templateId: "yasisland/yasislandvoicelayout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1784377715/yasIsland/yasHome.jpg",
  },
  emirates: {
    label: "Emirates",
    tagline: "Airline travel channel",
    templateId: "emirates/emirateschatlayout",
  },
};

/**
 * The client selected by the URL PATH (`/sab`, `/bpp`) → its key; anything else
 * (root `/`, unknown) → null, which the app renders as the Unoverse landing page.
 * Falls back to the legacy `?client=` query param so old demo links keep working.
 */
export function getRoute() {
  const seg = window.location.pathname.replace(/^\/+|\/+$/g, "").toLowerCase();
  if (clients[seg]) return seg;
  const q = new URLSearchParams(window.location.search).get("client")?.toLowerCase();
  return q && clients[q] ? q : null;
}
