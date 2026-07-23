# RestoraERP POS Terminal

Flutter POS terminal for RestoraERP, ported from the `/admin/pos` screen in the
Next.js frontend (`../../front`). Targets Android, iOS, Windows, Linux, and macOS.

Only users holding the `view_pos` permission (`pos_manager` and above) can log in.

## Requirements

Flutter 3.38+ and a JDK 17+ for Android builds. If Flutter is not on your `PATH`:

```fish
fish_add_path ~/flutter/bin
```

Android builds use Android Studio's bundled JDK 21, already configured via:

```bash
flutter config --jdk-dir=/snap/android-studio/current/jbr
```

### Linux desktop prerequisite

`flutter build linux` currently fails on this machine with
`/usr/bin/ld: cannot find -lstdc++`. Flutter's Linux toolchain hardcodes clang,
and clang 14 selects the newest GCC it can see — gcc-12 — but only
`libstdc++-11-dev` is installed, so gcc-12's `libstdc++.so` is missing. Fix with:

```bash
sudo apt install libstdc++-12-dev
```

This is an environment gap, not a code issue; Android builds and runs fine.

## Running

```bash
flutter pub get
flutter run                      # dev build   -> http://10.0.2.2:8029/api/v1
flutter run --dart-define=APP_ENV=staging
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8029/api/v1
```

`10.0.2.2` is the Android emulator's alias for your computer's `127.0.0.1`, so a
locally running `core-api` is reachable from the emulator without any extra setup.

## Build base URLs

The API base URL resolves in this order:

1. `--dart-define=API_BASE_URL=…` — explicit override, wins over everything.
2. The preset for `--dart-define=APP_ENV=dev|staging|prod`.
3. The `dev` preset.

Presets live in `lib/core/config/app_config.dart`:

| `APP_ENV` | Base URL                                |
| --------- | --------------------------------------- |
| `dev`     | `http://10.0.2.2:8029/api/v1`           |
| `staging` | `https://staging.restauraerp.com/api/v1`|
| `prod`    | `https://restauraerp.com/api/v1`        |

Non-production builds show an environment badge on the setup and login screens so
a staging terminal is never mistaken for a live one.

Release builds, per platform:

```bash
flutter build apk     --dart-define=APP_ENV=prod
flutter build appbundle --dart-define=APP_ENV=prod
flutter build ipa     --dart-define=APP_ENV=prod
flutter build linux   --dart-define=APP_ENV=prod
flutter build windows --dart-define=APP_ENV=prod
flutter build macos   --dart-define=APP_ENV=prod
```

To stop field terminals from being re-pointed at another server, add
`--dart-define=LOCK_SERVER_URL=true`. That hides the "Change" action and disables
the setup field, so the build-time URL is the only one available.

## Terminal setup and server management

The build-time URL is only a *default*. On first launch the terminal shows a setup
screen pre-filled with it — the operator confirms or edits the address, and it is
tested against the server before being saved. No one can log in until this passes.

The saved URL survives logout, and the login screen shows it with a **Change**
action, so the server can be managed between shifts without reinstalling.

Entering just a host is fine: `192.168.0.10:8029` becomes
`http://192.168.0.10:8029/api/v1`.

## Design system

Colours, radii, and semantics come from the `restoraerp` daisyUI theme in
`front/src/app/globals.css`, transcribed into `lib/ui/theme.dart` so the terminal
and the web admin read as one product:

| Token             | Value     | Use                        |
| ----------------- | --------- | -------------------------- |
| `primary`         | `#0F6E5C` | brand teal — CTAs, prices  |
| `secondary`       | `#F4A825` | amber accents              |
| `base-100`        | `#FAFAF8` | cards, sheets              |
| `base-200`        | `#F2F5F4` | page background            |
| `base-300`        | `#E4E7E6` | borders, dividers          |
| `base-content`    | `#1A1D1F` | primary text               |
| `success`         | `#1E8E5A` | applied discount, customer |
| `warning`         | `#F4A825` | held orders, hold action   |
| `error`           | `#D64545` | failures, clear action     |
| `info`            | `#2F80ED` | delivery order type        |

Radii follow the theme's `--radius-*` variables via `AppRadius`: `selector` 8px,
`field` 10px, `box` 16px. No widget hardcodes a colour or radius.

Order types are recoloured from the brand palette instead of the ad-hoc Tailwind
hues the web POS used inline, so all four stay distinguishable while belonging to
one system: dine-in teal, takeaway amber, delivery blue, catering green.

### Branding

The logo comes from `../../Assets/restaura-logo-square.png`, copied into
`assets/brand/`. Two icon sources are derived from it, since the full logo's
wordmark is illegible at launcher sizes:

- `icon-mark.png` — the teal mark alone
- `icon-adaptive-foreground.png` — the mark inset into Android's adaptive safe zone

Regenerate launcher icons for Android, iOS, macOS, and Windows after changing the
logo:

```bash
dart run flutter_launcher_icons
```

**Fonts** are not yet ported. The web uses Inter (body), Poppins (headings), and
Hind Siliguri (Bengali) via `next/font/google`; the terminal currently uses the
platform default. To match, drop the TTFs into `assets/fonts/`, declare them in
`pubspec.yaml`, and set `fontFamily` in `buildAppTheme()` — bundling rather than
using `google_fonts` keeps the terminal working offline.

## Architecture

```
lib/
  core/
    api/          ApiClient (bearer auth, JSON, {data:…} unwrapping), Session
    config/       AppConfig (build-time), ServerConfig (runtime URL)
  data/
    models/       Product, Category, Customer, Discount, Location, Table, User, Cart
    repositories/ AuthRepository, PosRepository
  state/          AuthController, PosController  (ChangeNotifier + provider)
  ui/
    login/        ServerSetupPage, LoginPage
    pos/          PosPage + widgets
```

`PosController` holds the whole POS screen's state — the direct counterpart of the
`useState` block in the React page.

### Auth

`/auth/login` returns a token and a bare user record **without** permissions, so
login is followed by `/auth/me`, which appends `all_permissions`. A user who
authenticates successfully but lacks `view_pos` is logged straight back out with an
explanatory message. Any `401` during a session drops the terminal to the login screen.

## Branch scoping

`users.location_id` is a `belongsTo`, so staff belong to exactly one branch. A
user with a branch is **pinned** to it: the switcher is hidden and their branch
shows as a read-only badge beside the search field. Only accounts with no branch
(admins overseeing every site) get the dropdown, and only when more than one
branch exists.

This matters for correctness, not just UI: `/locations` returns every branch
unscoped, so before this the terminal defaulted to the first one in the list — a
manager for one branch could file orders against another.

## Order management

`view_orders` puts an orders button in the POS app bar; `update_order_status`
enables the actions. Ported from the web `/admin/orders`:

- Tabs for all / dine-in / takeaway / delivery / catering, sorted by placement
  time, table, or delivery time.
- Cards showing status, payment state, a live "time since placed" counter,
  logistics for delivery and catering, and the line items.
- Status transitions per order type (`pending → cooking → cooked → served` for
  dine-in; `→ packed → picked → delivered` for delivery and catering).
- Payment with method selection and a coupon applied at the till, which
  recalculates tax and total before `PUT /orders/{id}`.
- Cancel, offered only before the food is cooked.
- Polls every 10 seconds, matching the web. Failures during a silent poll do not
  replace a screen full of orders with an error.

Orders are fetched with `location_id` so a busy branch does not download every
other branch's orders on each refresh.

## Printing

Kitchen tickets and customer receipts print as 80mm-roll PDFs through the
platform print dialog (Android print service, AirPrint, CUPS, Windows), which is
where a thermal printer appears once installed on the device.

- **Kitchen ticket** — order type, table or delivery time, and quantities set
  large with no prices.
- **Receipt** — itemised with totals and payment method. The header comes from
  `/website-settings` (`site_name`, `address`, `contact_phone`) rather than the
  hardcoded "123 Restaurant Street" in the web version.

Available from each order card, and straight after checkout.

`assets/fonts/ReceiptSans.ttf` is a 14KB subset of FreeSans covering ASCII plus
৳ and a few currency symbols. The PDF standard fonts have **no glyph for ৳**
(U+09F3), so without it every amount would print with a blank box. Regenerate the
subset if another currency is needed. For 58mm paper, change `_roll` in
`lib/services/ticket_printer.dart` to `PdfPageFormat.roll57`.

## Ported features

Order types (dine-in / takeaway / delivery / catering), location switching with
per-location product availability, category tabs with counts, product search, cart
with per-item notes, hold and recall orders, coupon codes validated locally,
customer search and inline creation, delivery time / address / charge, live totals
(subtotal, discount, 10% tax, delivery), and checkout to `POST /orders`.

**Layout:** on screens ≥900px the cart is a permanent right-hand column, matching
the web. On phones the catalogue fills the screen and the cart opens as a bottom
sheet from a bar showing the running total.

### Intentionally not ported

- **Google Places autocomplete** on address fields — the web version uses the
  Maps JS SDK. Addresses are plain text fields here; `latitude`/`longitude` are
  still sent when available. Adding this needs a Maps API key per platform.
- **"View on Maps" links** on delivery orders — the address and coordinates are
  shown, but opening an external maps app is not wired up.

## Tests

```bash
flutter test
```

Covers server-URL normalisation, per-location availability, discount maths,
tolerant JSON parsing, and the `view_pos` permission gate.

## Security notes

- The bearer token is stored with `shared_preferences`, which is **not encrypted
  at rest**. Adequate for a dedicated, physically controlled terminal; if these
  ever run on shared or personal devices, swap `Session` for
  `flutter_secure_storage` — nothing outside that class needs to change.
- Cleartext HTTP is permitted on Android (`network_security_config.xml`) and iOS
  (`NSAppTransportSecurity`) because on-premise servers are commonly plain HTTP on
  a LAN. For an internet-facing deployment, serve the API over HTTPS and tighten
  both files.
