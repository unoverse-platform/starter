/**
 * Experience analytics — the DELIVERY side (docs/unoverse/UNOVERSE_ANALYTICS.md).
 *
 * This runs in the HOST PAGE'S OWN REALM, which is the entire point. The visitor's
 * analytics client id lives in a first-party cookie on the customer's domain, and their
 * consent state, regional configuration and retention terms are already resolved by their
 * own tag. Calling that tag inherits all of it. A server-side call could inherit none of
 * it, and would file our events under a separate, unjoinable visitor.
 *
 * The app itself knows none of this: it posts an event across the iframe boundary and is
 * finished. Everything vendor-specific is here.
 */

/**
 * THE TARGET IS NAMED, NEVER DETECTED, AND NEVER FALLS BACK.
 *
 * A customer page routinely carries several analytics tools at once. Sniffing for whichever
 * global happens to exist would eventually push one customer's behavioural data into a
 * different vendor's property: a data protection incident, not a bug. So an absent target
 * means silence, warned once, and nothing is redirected anywhere.
 *
 * @param {{ target?: string, global?: string, measurementId?: string, debug?: boolean }} config
 */
export function createAnalyticsDelivery(config) {
  const target = config?.target;
  const globalName = config?.global || (target === "dataLayer" ? "dataLayer" : undefined);
  let warned = false;

  // OFF BY DEFAULT. No config means nothing is sent. Writing into a customer's property
  // means writing into their consent configuration and retention terms, so it is switched
  // on per tenant, deliberately.
  if (!target) return null;

  const missing = (why) => {
    if (warned) return;
    warned = true;
    console.warn(`[unoverse:analytics] not sending: ${why}. Events are being dropped.`);
  };

  return function deliver(event) {
    if (!event?.event) return;
    const name = event.event;
    // The author's params sit FLAT (what GTM variables and GA4 mappings read), the
    // platform's own vocabulary stays namespaced so it can never collide with a key the
    // host page already uses.
    const payload = { ...(event.params || {}), unoverse: event.context || {} };
    const win = typeof window !== "undefined" ? window : undefined;
    if (!win) return;

    try {
      if (target === "dataLayer") {
        const dl = win[globalName];
        // An array is the contract: GTM's snippet creates one, and pushing to a non-array
        // would throw or, worse, silently write onto some unrelated object.
        if (!Array.isArray(dl)) return missing(`window.${globalName} is not a dataLayer array`);
        dl.push({ event: name, ...payload });
      } else if (target === "gtag") {
        if (typeof win.gtag !== "function") return missing("window.gtag is not a function");
        // `send_to` pins ONE property when the page configures several; without it gtag
        // fires to all of them.
        if (config.measurementId) payload.send_to = config.measurementId;
        win.gtag("event", name, payload);
      } else if (target === "custom") {
        const fn = globalName ? win[globalName] : undefined;
        if (typeof fn !== "function") return missing(`window.${globalName} is not a function`);
        fn(name, payload);
      } else {
        return missing(`unknown target "${target}"`);
      }
      if (config.debug) console.log(`[unoverse:analytics] sent ${name} → ${target}`, payload);
    } catch (err) {
      // FAILURE IS SILENT AND CLOSED: measurement never breaks the experience it measures.
      console.warn(`[unoverse:analytics] ${name} failed: ${err?.message ?? err}`);
    }
  };
}
