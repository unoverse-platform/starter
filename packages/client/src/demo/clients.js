// THE DEMO SITE'S CHANNEL REGISTRY — which fake page sits behind which template.
//
// Demo-only. The embeddable client (../embed) never reads this: it is handed a templateId,
// because a real customer has one app and no registry. Where the platform lives is a
// different question and belongs to the embed — see ../embed/config.js.

export { config } from "../embed/config";
import { config } from "../embed/config";

// ANALYTICS (docs/unoverse/UNOVERSE_ANALYTICS.md) is configured HERE, per channel, and
// deliberately NOT in the template. Two reasons, one architectural and one conceptual:
//
//   1. The code that delivers an event runs in THIS realm, outside the iframe. Templates
//      load inside it. Config placed in a template cannot reach the delivery code.
//   2. The dataLayer's name belongs to the customer's PAGE, not to the design. The same
//      template rendered on their site, in this client and in an MCP app host needs three
//      different answers; the template is identical in all three.
//
// Shape (all optional; absent `analytics` means nothing is sent, which is the default):
//   analytics: { target: "dataLayer" | "gtag" | "custom",
//                global: "<window global name>",     // named, never detected
//                measurementId: "G-XXXXXXX",         // gtag only, pins ONE property
//                debug: false }                      // console.log each event
//
// Demo client registry — each entry is one CHANNEL skin: which template the app loads
// and which "fake page" screenshot sits behind the drawer. Each client is its own PATH
// route (`/sab`, `/bpp`) so the URL alone opens that channel's chat — no launcher, no
// query param. The Unoverse landing page (`/`) links out to each. Template ids MUST be
// fully org-qualified (`<org>/<name>`, e.g. `bpp/bpp-chat-layout`) — bare names are not relied on.
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
    templateId: "bpp/bpp-chat-layout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1783256770/bppWeb_c9bila.png",
  },
  yas: {
    label: "Yas Island",
    tagline: "Destination experiences channel",
    templateId: "yasisland/yas-island-chat-layout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1784377715/yasIsland/yasHome.jpg",
    // No public flag here: whether this channel needs a login is the SERVER's answer
    // (/.well-known/unoverse-app/<org>/<app>), derived from the workflow trigger's
    // auth/public toggle on the canvas.
  },
  yasvoice: {
    label: "Yas Island Voice",
    tagline: "Voice concierge channel",
    templateId: "yasisland/yas-island-voice-layout",
    background: "https://res.cloudinary.com/sonik/image/upload/v1784377715/yasIsland/yasHome.jpg",
  },
  emirates: {
    label: "Emirates",
    tagline: "Airline travel channel",
    templateId: "emirates/emirates-chat-layout",
  },
};

