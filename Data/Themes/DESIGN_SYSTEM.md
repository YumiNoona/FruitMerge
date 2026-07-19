# Fruit Merge cozy design system

## Visual language

The interface uses soft cream surfaces, peach/coral actions, leaf-green primary controls, warm brown type, thick light borders, and low soft shadows. Gameplay remains the brightest focal area; chrome stays compact and translucent.

## Palette

- Cream canvas: `#FFF7E8`
- Warm panel: `#FFF0D6`
- Peach panel: `#FFC79E`
- Primary green: `#A6C94A`
- Pressed green: `#7AA638`
- Action orange: `#F78C47`
- Coral accent: `#FF8270`
- Coin gold: `#FFB833`
- Ink brown: `#5C331C`
- Shop locked coral: `#FF8566`
- Shop selectable gold: `#FFB340`
- Shop active teal: `#4CBF94`

## Typography

The complete UI uses `Assets/Fonts/NERILLKID Trial.ttf`. Cloudy, Atop, Spenbeb,
and system-font fallback stacks are retired from UI scenes. Titles use a cream
outline and a soft offset shadow. Body copy stays at 16–20 px; touch labels use
21–27 px; key score and heading values use 36–76 px.

## Components

- Primary button: green, 28 px radius, 4 px cream border.
- Orange button: secondary navigation and shop actions.
- Cream button: tabs, utility actions, and quiet navigation.
- Panel: cream at 96% opacity with a peach border and 5–8 px shadow.
- Interactive cards/buttons: shallow 2–4 px, low-opacity shadows; avoid dark 7–9 px blocks.
- Shop card: three-column 210 × 320 minimum card with contained 150 px art. Pet flavor descriptions stay hidden and are replaced by concise two-line ability summaries; all summary copy uses 16 px outlined NERILLKID text.
- Scroll catalog: retain wheel/touch scrolling but hide the visual scrollbar so it never cuts into the rightmost cards.
- Settings rows: 62 px high with 12 px vertical gaps; Music, Sound Effects, and Vibration only.
- Shop tabs: peach idle, sunny-orange hover, and leaf-green active.
- Shop action state: green ready, coral locked, gold selectable, teal active.
- Tooltip: cream surface, coral border, dark-brown NERILLKID label.
- Wallet counters: show exact values through 999, then compact to one-decimal `K`/`M` notation; prices and reward amounts remain exact.
- HUD: one compact top card, a visible next-fruit preview (plus Banana Fox's optional second preview), three loadout-filtered power slots under `PowerupColumn`, and an interruptible pause overlay. There is no fruit-progression dock, separate mode label, or power tray panel; Time Attack reuses the score caption.

## Companion presentation

The in-world equipped pet is a minimum 128 px diameter mobile target. Charged
companions use a five-pixel colored progress ring and a short `TAP PET!` callout.
Ability activation uses one jump/squash gesture, a small particle burst, a bright
procedural chirp, and the standard power haptic. Reduced Motion keeps the callout,
sound, particles, and gameplay effect while removing the jump/rotation tween.

## Motion

Buttons scale to 102.5% on hover and 96.5% while pressed. Popups enter with a short back-eased scale. Merge feedback is quick and elastic; no long blocking animation is used during active play.
