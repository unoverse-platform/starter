// Where the platform is — the only configuration the EMBED needs, all from Vite env
// vars (VITE_*), baked at build time.
//
// This client knows only a TEMPLATE name + where the server is. It loads
// `unoverse://templates/<name>` and renders it. If that template carries a
// workflow `binding` (the §4b app manifest), the client opens the data-plane and
// the workflow streams live components in; a plain template just renders its own
// welcome/default state. The workflow binding is never hardcoded here.
//
// The demo's channel registry (which fake page sits behind which template) is NOT here:
// it is the fake website's business, and lives in ../demo/clients.js.

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
  templateId: import.meta.env.VITE_TEMPLATE_ID || "sab/sab-chat-layout",
};
