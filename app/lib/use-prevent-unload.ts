"use client";

import { useEffect } from "react";

/**
 * Warns before the page unloads while `active` is truthy.
 * Used by editors that hold unsaved draft state.
 */
export function usePreventUnload(active: unknown): void {
  useEffect(() => {
    if (!active) return;
    const preventUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", preventUnload);
    return () => window.removeEventListener("beforeunload", preventUnload);
  }, [active]);
}
