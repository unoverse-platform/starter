import { UnoverseMark } from "./Logo";

// Floating chat launcher — the only thing visible over the fake page until the
// user opens the drawer. Ported from legacy GravitySAB, rebranded with the
// official Unoverse logomark.
export function ToggleChatButton({ onClick, position = "fixed bottom-7 left-8" }) {
  return (
    <div className={`${position} z-[9999]`}>
      <div className="relative">
        <div
          className="absolute -inset-1 rounded-full blur-sm opacity-20 animate-pulse"
          style={{ background: "linear-gradient(135deg, rgba(211,49,49,0.4) 0%, rgba(184,42,42,0.4) 100%)" }}
        />

        <button
          onClick={onClick}
          aria-label="Open chat"
          className="
            relative group flex items-center justify-center
            w-20 h-20 rounded-full shadow-lg hover:shadow-xl
            transform hover:scale-110 transition-all duration-300 ease-in-out
          "
          style={{ background: "linear-gradient(135deg, #d33131 0%, #b82a2a 100%)" }}
        >
          <UnoverseMark
            size={40}
            className="transform group-hover:scale-110 transition-transform duration-300"
          />
          <span
            className="
              absolute left-full ml-4 bg-white px-3 py-2 rounded-lg
              text-base font-medium text-red-700 shadow-md
              opacity-0 group-hover:opacity-100 transition-opacity duration-300 whitespace-nowrap
            "
          >
            Chat with Unoverse
          </span>
        </button>
      </div>
    </div>
  );
}

export default ToggleChatButton;
