import { useEffect } from "preact/hooks";
import { useAuth } from "react-oidc-context";
import { getRoute } from "../lib/config";
import { hasAuth } from "../lib/auth";
import { LandingPage } from "./LandingPage";
import { ClientDemo } from "./ClientDemo";

/**
 * Top-level path router. The URL alone decides what mounts:
 *   `/`             → the Unoverse hub (login-gated; one card per demo channel)
 *   `/logout`       → full Auth0 SSO sign-out, then back to the login gate
 *   `/sab`, `/bpp`,
 *   `/yas`, `/emirates` → that channel's live demo
 *
 * Navigation between them is a full page load, so this only ever mounts one branch per
 * session — no conditional hooks, and each channel boots a clean iframe. (The legacy
 * `?logout` query param still works on a channel route — see ClientDemo.)
 */
export function App() {
  const path = window.location.pathname.replace(/^\/+|\/+$/g, "").toLowerCase();
  if (path === "logout") return <LogoutRoute />;

  const route = getRoute();
  return route ? <ClientDemo clientKey={route} /> : <LandingPage />;
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
