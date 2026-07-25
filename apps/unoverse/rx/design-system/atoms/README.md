# Atoms (`rx/atoms/`)

The smallest reusable component definitions — the **atomic-design tier** below
`rx/components/`. Buttons, badges, avatars, inputs, tags. Each is a self-contained
neutral primitive tree (same schema as components).

## An atom owns its OWN style (referencing tokens)

A component's appearance lives in its **definition** — the atom carries its full style,
referencing `rx/styles` **tokens** (colors, spacing, type). It is the **single home** for
that component's look. The SDK never styles it; `rx/styles` holds tokens, not component
recipes. So the Button's style belongs **here**, in `button.json`.

## Composition (how components use an atom)

A component composes an atom with a **`Ref`** node — the server inlines the atom's tree and
**remaps** the atom's prop fields to the host's fields:

```jsonc
// in a component definition (e.g. card.json):
{ "type": "Ref", "ref": "Button", "visibleWhen": "callToAction", "props": { "label": "callToAction" } }
// → server expands to the Button atom's <Button> node, with bind.label = "callToAction".
```

Atoms are **never served standalone** — `loadDefinition` expands all `Ref`s, so a channel only ever
receives a fully-expanded primitive tree. This is why the Button's style lives **here** (the atom),
not as a recipe in `rx/styles` and not in the SDK.

**Atoms are NOT served to channels — or shown anywhere.** There is no
`unoverse://atoms/{name}` resource and no Studio view. Atoms are *authoring-time
only* — they exist to be **composed/inlined into components + templates**; a channel
only ever receives fully-expanded component/template definitions.

## Atoms vs primitives vs components

| | What | Where |
|---|---|---|
| **Primitive** | the ~12 native widgets (`Box`, `Text`, `Image`, `Button`, …) | the SDK (native code) |
| **Atom** | a small, standardized definition over primitives (`Button`, `Badge`) | `rx/atoms/` (data) |
| **Component** | a larger composition (`Card`, `BookingWidget`) | `rx/components/` (data) |

Atoms reference **semantic tokens** from `rx/styles/` (e.g. `action.primary`,
`text.primary`), exactly like components — so they restyle with the theme.

## Ref overrides (per-host customization)

`loadDefinition` expands every `Ref` into the atom's primitive tree. Beyond `props`
(field remapping), a `Ref` may override four things — for the parts an atom can't
carry itself:

| Override | Use |
|---|---|
| `with` | pass **literals** into the atom — `{ "type": "Ref", "ref": "button", "with": { "label": "Learn more", "icon": "arrowRight" } }`. A bind whose field is a `with` key becomes a hardcoded attribute; a truthy `with` key satisfies (drops) a matching `visibleWhen` guard (unprovided key ⇒ that piece stays hidden); `{{key}}` style bindings take the literal value |
| `visibleWhen` | gate the whole atom (e.g. `{ "type": "Ref", "ref": "Button", "visibleWhen": "callToAction" }`) |
| `style` | merge style onto the root (e.g. a `pill` with a different `background` tone) |
| `action` | replace the atom's action — the per-host behaviour an atom can't bake in (e.g. each wizard step's option writes different fields) |

`props` also remaps `{{field}}` bindings inside **style** values (a `match-gauge`'s
`radial.at: "{{value}}"` → `{{matchScore}}`), so data-driven looks are parameterizable too.

An atom can be an `Each` `template` — the option `choice-row` in `CardFinder` is a `Ref`
inside an `Each`, reading per-item fields (`label`/`description`/`icon`) from the Each scope
while the `Ref` supplies the step's `action`. This is how `CardFinder`'s 8 question steps
collapse onto one `section-header` + one `choice-row` atom.
