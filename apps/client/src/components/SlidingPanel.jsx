import { useState, useEffect } from "preact/hooks";
import { useWidget } from "../hooks/useWidget";
import { ToggleChatButton } from "./ToggleChatButton";

// Left-side chat drawer + floating launcher. Ported from legacy GravitySAB.
//
// The drawer starts CLOSED over the static "fake" page — the floating launcher is the only
// thing visible until the user opens it. When the drawer closes we wait for the slide-out
// transition to finish, THEN unmount the children — so the Unoverse SDK tears down its
// WebSocket/stream gracefully rather than mid-animation.
export function SlidingPanel({ children, width = "420px" }) {
  const { isOpen, open, close } = useWidget();

  const [isMounted, setIsMounted] = useState(isOpen);
  useEffect(() => {
    if (isOpen) {
      setIsMounted(true);
      return;
    }
    // Match the 300ms transition on the panel below before unmounting.
    const t = setTimeout(() => setIsMounted(false), 320);
    return () => clearTimeout(t);
  }, [isOpen]);

  // The APP owns the close control (its own top-right X) — it posts `unoverse:close`, and the
  // host slides the drawer shut (the launcher reappears). No host-drawn X, so it never clashes
  // with the app's focus-mode X.
  useEffect(() => {
    const onMessage = (e) => {
      if (e.data?.type === "unoverse:close") close();
    };
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [close]);

  return (
    <div className="h-full">
      {/* Sliding panel */}
      <div
        className={`fixed inset-y-0 left-0 bg-white shadow-2xl transform transition-all duration-300 ease-in-out z-[9999] ${
          isOpen ? "translate-x-0" : "-translate-x-full"
        }`}
        style={{ width }}
      >
        {/* Content — unmounted once the drawer is fully closed so the chat
            session (connection, stream) ends gracefully. */}
        <div className="h-full overflow-y-auto">{isMounted ? children : null}</div>
      </div>

      {/* Launcher (shown when the drawer is closed) */}
      {!isOpen && <ToggleChatButton onClick={open} />}
    </div>
  );
}

export default SlidingPanel;
