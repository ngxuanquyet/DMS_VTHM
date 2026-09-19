---
name: VTHM Industrial Heritage
colors:
  surface: '#F7FAF6'
  surface-dim: '#d5dccf'
  surface-bright: '#f5fcee'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff6e8'
  surface-container: '#e9f0e3'
  surface-container-high: '#e4eadd'
  surface-container-highest: '#dee5d8'
  on-surface: '#181C1B'
  on-surface-variant: '#3f4a3b'
  inverse-surface: '#2c3229'
  inverse-on-surface: '#ecf3e6'
  outline: '#6F7A74'
  outline-variant: '#becab7'
  surface-tint: '#006e15'
  primary: '#006e15'
  on-primary: '#ffffff'
  primary-container: '#47b347'
  on-primary-container: '#003f08'
  inverse-primary: '#71de6c'
  secondary: '#2e5da8'
  on-secondary: '#ffffff'
  secondary-container: '#84aefe'
  on-secondary-container: '#003f87'
  tertiary: '#ab2c5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#fd6c9d'
  on-tertiary-container: '#6e0034'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#8dfb85'
  primary-fixed-dim: '#71de6c'
  on-primary-fixed: '#002202'
  on-primary-fixed-variant: '#00530e'
  secondary-fixed: '#d7e2ff'
  secondary-fixed-dim: '#acc7ff'
  on-secondary-fixed: '#001a40'
  on-secondary-fixed-variant: '#09458e'
  tertiary-fixed: '#ffd9e1'
  tertiary-fixed-dim: '#ffb1c5'
  on-tertiary-fixed: '#3f001b'
  on-tertiary-fixed-variant: '#8b0e46'
  background: '#f5fcee'
  on-background: '#171d15'
  surface-variant: '#E0E3E0'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 45px
    fontWeight: '600'
    lineHeight: 52px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-md:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-sm:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm-mobile:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.15px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  margin-mobile: 16px
  margin-tablet: 24px
  gutter: 16px
  stack-sm: 4px
  stack-md: 12px
  stack-lg: 24px
---

## Brand & Style
The design system reflects the intersection of traditional Vietnamese craftsmanship and modern industrial efficiency. The aesthetic is **Corporate / Modern**, heavily influenced by Material Design 3 principles but refined for a premium enterprise context.

The UI evokes a sense of "Structured Prestige"—it is organized and feature-rich without feeling cluttered. It prioritizes clarity for field operations while maintaining the high-status feel of a market-leading manufacturing group. High-quality whitespace and intentional green accents suggest growth, stability, and environmental responsibility.

## Colors
The palette is centered around the vibrant green from the brand identity, establishing a more energetic yet professional industrial presence.

- **Primary**: A bright, technical green (#47B347) derived from the logo. This color is reserved for high-priority interactive elements including primary buttons, active navigation markers, and progress indicators.
- **Secondary**: A deep industrial blue (#3361AC) used for supporting brand elements and secondary accents to ground the vibrant primary green.
- **Neutral**: "Paper White" (#F7FAF6) serves as the base background to maintain a high-contrast, clean environment suitable for professional data entry and monitoring.
- **Surface Strategy**: A 75% white dominance is maintained to ensure the interface feels airy and modern despite the high information density.

## Typography
This design system utilizes **Inter** for its exceptional legibility on mobile displays and its systematic, utilitarian feel. 

Headlines use a semi-bold weight (`600`) to provide clear anchoring for technical data. Body text remains at a standard weight with slightly increased line heights to ensure readability during field operations in varying light conditions. For data-heavy labels, use `label-lg` in medium weight to distinguish from standard body text.

## Layout & Spacing
The layout follows a **Fluid Grid** model optimized for professional handheld devices and field tablets.

- **Mobile**: 4-column grid with 16px side margins.
- **Tablet**: 8-column grid with 24px side margins.
- **Spacing Rhythm**: All measurements are multiples of 8px. Use 16px (2x) for standard padding within cards and 12px (1.5x) for tighter grouping in data lists to balance density with tap-target accessibility.

The layout focuses on verticality, utilizing a bottom-heavy navigation model to ensure one-handed ease of use for field workers during inspections.

## Elevation & Depth
Depth is communicated through **Tonal Layers** combined with **Ambient Shadows** to create a structured hierarchy without visual clutter.

- **Level 0 (Base)**: The background surface (#F7FAF6) provides the canvas.
- **Level 1 (Cards/Lists)**: White surfaces with a subtle 1px outline (#E0E3E0) serve as the primary work container.
- **Level 2 (Interactive)**: Hovered or active states employ a soft, diffused shadow (Y: 2, Blur: 4, 10% black) to lift them from the base.
- **Level 3 (Overlays/FAB)**: Floating Action Buttons and modal dialogs use a pronounced shadow (Y: 4, Blur: 8, 12% black) to establish peak hierarchy.

Shadows should be neutral or slightly tinted with the secondary blue to maintain a crisp, industrial feel.

## Shapes
The shape language is **Rounded**, following a systematic approach to corner radii that balances "engineered precision" with "modern software."

- **Standard Cards**: 16px (rounded-lg) for a modern, approachable container style.
- **Input Fields & Buttons**: 8px (rounded) to maintain professional, structural rigidity.
- **Chips & FABs**: Full pill-shaped (rounded-xl/capsule) to distinguish them as tactile, interactive elements.

## Components
- **Primary Buttons**: Must use the exact brand green (#47B347) with white text. Apply an 8px corner radius.
- **Bottom Navigation**: Use a container-less design. The active state is indicated by a pill-shaped tonal background in the primary green behind the active icon.
- **Progress Indicators**: Both circular loaders and linear step-progress bars must utilize the primary green (#47B347) to signal active movement and system health.
- **Floating Action Buttons (FAB)**: High-visibility primary green circular buttons placed in the bottom right for brand-critical actions like "Start Inspection."
- **Status Chips**: Use low-opacity tints of the primary green (10%) for "Success" or "Completed" states, paired with full-saturation green text for high legibility.
- **Vertical Timelines**: For manufacturing logs, use a 2px vertical stroke in light gray with Primary Green (#47B347) circular nodes representing completed or current milestones.
- **Input Fields**: Focus states must transition the bottom-line or outline stroke to the primary green to provide clear user feedback.