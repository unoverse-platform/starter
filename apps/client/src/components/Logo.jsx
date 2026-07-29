// The official Unoverse logomark — the white swirl, served from Cloudinary (same asset the
// Unoverse Studio header uses). It's a white PNG, so it sits on dark surfaces; on light
// chrome use a dark backing (see the demo home pill).
const MARK_SRC = "https://res.cloudinary.com/sonik/image/upload/v1751802699/gravity/icons/logo_white.png";

export function UnoverseMark({ size = 40, className = "" }) {
  return (
    <img
      src={MARK_SRC}
      alt="Unoverse"
      width={size}
      height={size}
      className={`object-contain ${className}`}
      style={{ width: size, height: size }}
    />
  );
}

// Full lockup: logomark + lowercase "unoverse" wordmark (matches the Studio brand).
export function UnoverseLogo({ size = 40, tone = "light", className = "" }) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <UnoverseMark size={size} />
      <span
        className={`font-semibold lowercase tracking-tight ${tone === "dark" ? "text-gray-900" : "text-white"}`}
        style={{ fontSize: size * 0.6 }}
      >
        unoverse
      </span>
    </span>
  );
}
