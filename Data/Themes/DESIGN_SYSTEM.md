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
- Shop card: three-column 210 × 320 minimum card; pet art expands to 200 px and pet descriptions stay hidden. Skin/power-up descriptions use 16 px outlined body text in a 50 px two-line row.
- Scroll catalog: retain wheel/touch scrolling but hide the visual scrollbar so it never cuts into the rightmost cards.
- Settings rows: 62 px high with 12 px vertical gaps; Music, Sound Effects, and Vibration only.
- Shop tabs: peach idle, sunny-orange hover, and leaf-green active.
- Shop action state: green ready, coral locked, gold selectable, teal active.
- Tooltip: cream surface, coral border, dark-brown NERILLKID label.
- HUD: one compact top card, a visible next-fruit preview, and an interruptible pause overlay.

## Motion

Buttons scale to 102.5% on hover and 96.5% while pressed. Popups enter with a short back-eased scale. Merge feedback is quick and elastic; no long blocking animation is used during active play.
