import { useState, useCallback } from "preact/hooks";

// Drawer open/close state for the chat launcher. Ported from the legacy GravitySAB
// hook of the same name. A module-level setter is stashed so the panel can also be
// driven from outside React (e.g. a host-page script) via openWidget/closeWidget.
let globalSetIsOpen = null;

export function useWidget() {
  const [isOpen, setIsOpen] = useState(false);

  // Expose the setter for out-of-tree control (one consumer: SlidingPanel).
  globalSetIsOpen = setIsOpen;

  const open = useCallback(() => setIsOpen(true), []);
  const close = useCallback(() => setIsOpen(false), []);
  const toggle = useCallback(() => setIsOpen((prev) => !prev), []);

  return { isOpen, open, close, toggle };
}

// Global control functions — handy for triggering the chat from host-page code.
export const openWidget = () => globalSetIsOpen?.(true);
export const closeWidget = () => globalSetIsOpen?.(false);
