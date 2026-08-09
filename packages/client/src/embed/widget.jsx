import { render } from "preact";
import { AuthProvider } from "react-oidc-context";
import { UnoverseWidget } from "./UnoverseWidget";
import { oidcConfig, hasAuth } from "./auth";
import { config } from "./config";
import "../index.css";

/**
 * THE EMBED ENTRY — what a customer's page loads:
 *
 *   <script src="unoverse-demo.js" data-app="bpp/bpp-chat-layout"></script>
 *
 * ONE FILE, one tag. The stylesheet is injected from this bundle at runtime (see
 * vite.config.js), so there is no second tag to forget.
 *
 * WHICH APP COMES FROM THE TAG, not the URL. The demo site picks its channel from the path
 * (`/sab`, `/bpp`) because it owns every path it serves; on a customer's site the path is
 * theirs and means nothing to us. The tag is the only thing we can be certain is ours.
 *
 * Everything else is already baked in at build time (VITE_UNOVERSE_URL, VITE_AUTH_*), so a
 * customer configures nothing at runtime and cannot point the widget at the wrong server.
 * Auth is the HOST's: their own IdP, their own origin, their own callback registration —
 * unoverse only verifies the resulting token, and answers separately (via authRequired)
 * whether this app needs one at all.
 */

// `document.currentScript` is only set while a classic script is EXECUTING, so it must be
// read here at module top level — by the time a callback runs it is null. The querySelector
// fallback covers a page that inlined or re-hosted the bundle, where currentScript is not ours.
const tag = document.currentScript ?? document.querySelector("script[data-app]");
const templateId = tag?.dataset?.app || config.templateId;

/** Where to draw. A named target lets a page place the launcher inside its own layout;
 *  without one we append our own element, which is the common case. */
function mountPoint() {
  const selector = tag?.dataset?.target;
  if (selector) {
    const el = document.querySelector(selector);
    if (el) return el;
    console.warn(`[unoverse] data-target "${selector}" matched nothing — appending to <body>.`);
  }
  let host = document.getElementById("unoverse-widget");
  if (!host) {
    host = document.createElement("div");
    host.id = "unoverse-widget";
    document.body.appendChild(host);
  }
  return host;
}

// The widget is a CHANNEL: it owns auth. With OIDC configured we wrap in react-oidc-context
// so a real JWT rides the connection; unset → no provider (useAuth() returns undefined) and
// the client talks anonymously, which unoverse allows only for a public app.
const tree = hasAuth ? (
  <AuthProvider {...oidcConfig}>
    <UnoverseWidget templateId={templateId} />
  </AuthProvider>
) : (
  <UnoverseWidget templateId={templateId} />
);

function mount() {
  render(tree, mountPoint());
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mount);
} else {
  mount();
}
