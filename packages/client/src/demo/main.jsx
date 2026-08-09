import { render } from "preact";
import { AuthProvider } from "react-oidc-context";
import { App } from "./App";
import { oidcConfig, hasAuth } from "../embed/auth";
import "../index.css";

/**
 * THE DEMO HUB's entry — an ordinary SPA mount into #app, nothing self-mounting about it.
 *
 * The self-mounting entry is the EMBED's (../embed/widget.jsx), which has to find its own
 * footing on a page it knows nothing about. This one owns its whole document, so it just
 * renders into the element index.html gave it.
 *
 * The hub signs in because it is login-gated; the channels it links to are static pages that
 * carry their own <script> tag and their own session.
 */
const tree = hasAuth ? (
  <AuthProvider {...oidcConfig}>
    <App />
  </AuthProvider>
) : (
  <App />
);

render(tree, document.getElementById("app"));
