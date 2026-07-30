import { render } from "preact";
import { AuthProvider } from "react-oidc-context";
import { App } from "./components/App";
import { oidcConfig, hasAuth } from "./lib/auth";
import "./index.css";

// The widget is a CHANNEL: it owns auth. When OIDC env vars are set we wrap in
// react-oidc-context so the user can sign in and a real JWT rides the connection.
// Unset → no provider (useAuth() returns undefined; the client talks anonymously).
const tree = hasAuth ? (
  <AuthProvider {...oidcConfig}>
    <App />
  </AuthProvider>
) : (
  <App />
);

// Self-mounting embeddable widget.
// Finds an existing #unoverse-demo host, or creates one and appends it to <body>.
// The SDK renders inside its own Shadow DOM, so host-page CSS never leaks in or out
// — no shell stylesheet of our own is needed.
function mount() {
  let host = document.getElementById("unoverse-demo");
  if (!host) {
    host = document.createElement("div");
    host.id = "unoverse-demo";
    document.body.appendChild(host);
  }
  render(tree, host);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mount);
} else {
  mount();
}
