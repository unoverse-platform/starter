import { useEffect } from "preact/hooks";
import { useAuth } from "react-oidc-context";
import { hasAuth } from "../embed/auth";
import { LandingPage } from "./LandingPage";

/**
 * The demo HUB, and only the hub:
 *   `/`        → one card per channel (login-gated)
 *   `/logout`  → full Auth0 SSO sign-out, then back to the login gate
 *
 * The channels themselves are NOT routes here any more. Each is a static page
 * (`/bpp.html`, `/sab.html`…) that carries a screenshot and one <script> tag, because that
 * is what a customer's site is: someone else's HTML plus our one line. Rendering them as
 * Preact routes meant the demo tested a component the customer never loads.
 */
export function App() {
  const path = window.location.pathname.replace(/^\/+|\/+$/g, "").toLowerCase();
  return path === "logout" ? <LogoutRoute /> : <LandingPage />;
}

/**
 * `/logout` — a HOST concern (the channel holds the session). Runs the OIDC sign-out redirect
 * (Auth0), which returns to the login gate. Requires Auth0's "Allowed Logout URLs" to include
 * this origin. With no OIDC configured there's no session to end, so we just go home.
 */
function LogoutRoute() {
  const auth = useAuth();
  useEffect(() => {
    if (!hasAuth) {
      window.location.replace("/");
      return;
    }
    if (!auth || auth.isLoading) return; // wait for the provider to settle, then sign out
    auth.signoutRedirect();
  }, [auth?.isLoading]);

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-[#0a0a12] text-sm text-white/60">
      Signing out…
    </div>
  );
}
