# Call Mom v1.0.1 — MikeGyver Studio

## v1.0.1 — the fix for the cellphone-callback timeout (Nov 6, 2026)

**What you saw:** Call Mom opened Safari to `voice.google.com`, and
Google Voice then tried to call your cellphone first to connect you to
Mom — and that just timed out.

**Why:** Safari is not the Voice app, so it doesn't use the app's
"Prefer Wi-Fi and mobile data" setting. Google says: "If you start a
call from the phone app on your device instead of the Voice app, the
call uses minutes from your mobile phone plan. To use Wi-Fi for a
call, start the call from the Voice app." The web flow is a callback:
Google Voice first calls your linked cell number, then connects you
to Mom. In Airplane Mode + Wi-Fi that callback can never arrive.

**Fix in v1.0.1:** the big button now stays in the Voice app:
1. Try the same `voice.google.com` URL as a universal link
   (`.universalLinksOnly: true`) — if Voice claims the domain, iOS
   opens it IN the app, with the number pre-filled, on Wi-Fi.
2. Otherwise open `googlevoice://` directly, with Mom's number
   already copied to the clipboard. No documented
   `googlevoice://call` form exists, so if Voice opens to its home
   screen, tap Calls > keypad, long-press to paste, and call.
   That's 2 taps, and it's a real in-app Wi-Fi call.
3. Safari web is kept only as a small labelled fallback —
   "Web (carrier callback)" — never the default.

**To update:** repo already exists, so do NOT delete
`E:\Downloads\mikegyver-callmom`. Save `callmom-v1.0.1.zip` +
`push-callmom.ps1` in `E:\Downloads`, unblock + run the script, then
run the TestFlight workflow by hand as before. Test again at home in
Airplane Mode + Wi-Fi: it must open the Voice app, not Safari.


One number, one big button, cruise-ship Wi-Fi.

Mike calls his Mom from a cruise ship off the Yucatán / Jamaica on decent
ship Wi-Fi. This app does **not** dial by itself and does **not** use the
carrier. It hands off to Google Voice over Wi-Fi/data, using Google's own
click-to-call URL — the reliable path, not an undocumented scheme.

**Bundle ID:** `studio.mikegyver.callmom`
**Display name:** Call Mom — **SKU:** callmom-001
**Repo:** `MikeGyver-SME/mikegyver-callmom` (create empty first)
**Version / build:** 1.0.1 (2) — iOS 17+, iPhone only, portrait
**No widget.** Single target, so no WidgetBundle / 90896 risk.

## How the call actually works

1. You tap the big green **Call Mom** button.
2. The app confirms, copies Mom's number, then tries to open the
   official Google Voice URL `https://voice.google.com/u/0/calls?a=nc,%2B<digits>`
   as a universal link — in the Voice app, not Safari. Google
   documents this URL form: "In the address bar, enter
   `https://voice.google.com/u/0/calls?a=nc,%2Bphonenumber`. Make sure to
   replace phonenumber with the number you want to call without hyphens."
   (support.google.com/voice/answer/3379129 — e.g. `…%2B18005550111`).
   In the app it dials with your Google Voice number as caller ID,
   over Wi-Fi/data — free to US/Canada numbers.
3. If the universal link doesn't land in the app, Call Mom opens
   `googlevoice://` directly with the number already copied — tap
   Calls > keypad in Voice, paste, call.
4. Safari web is an explicit fallback only ("Web (carrier callback)").
   It calls your cellphone first — do not use it in Airplane Mode.
5. `tel:` is deliberately **not** used. `tel:` uses carrier voice —
   on a cruise ship that's maritime roaming, not Wi-Fi.

Mom's number is stored only in this iPhone's UserDefaults
(`@AppStorage`). It is never uploaded, never in the repo, never in
this README. Enter it in the app under Edit — US 10 digits, +1 added
automatically. International numbers need the full country code.

## 1. Before you sail — do this at home

Do all of this **before** you leave port. Do not discover it on the ship.

1. **Google Voice → Prefer Wi-Fi and mobile data.**
   Google Voice app → Settings → Make and receive calls → select
   **Prefer Wi-Fi and mobile data**. NOT "Use carrier only" (the default).
   This is the setting that forces Voice to use the internet instead of
   your carrier minutes. If the connection gets weak Google may offer to
   fall back to carrier — decline it on the ship, or you'll roam.
2. **Install Google Voice** from the App Store and sign in. Make one
   test call from home first.
3. **Test exactly like the ship:** iPhone → Airplane Mode **ON**,
   Wi-Fi **ON**, join your home Wi-Fi, open Call Mom, tap Call Mom.
   If it works there, the handoff works. If it doesn't, fix it on land.
4. **On the ship:** Airplane Mode ON, Wi-Fi ON, connect to ship Wi-Fi,
   Data Roaming OFF, Cellular Data OFF. This is the standard cruise
   advice: Airplane Mode + Wi-Fi avoids accidentally joining the ship's
   cellular network and incurring roaming charges.
5. **Know the limits:** Google Voice can't call 911 — use the ship's
   phone / crew for emergencies. Ship Wi-Fi can block or degrade VoIP
   (UDP ports, captive portal, congestion). If a call won't connect,
   try again near an access point / on deck, or in port on shore Wi-Fi.
   Calls to a US number are free over Wi-Fi; international destinations
   pay Google Voice international rates even over Wi-Fi.

## 2. What the app shows you

- **Wi-Fi status** (NWPathMonitor): "Wi-Fi — good for Google Voice" /
  "Cellular — avoid on the ship" / "No connection".
- **Voice app ✓ / ?** — `canOpenURL(googlevoice://)`; needs
  `LSApplicationQueriesSchemes = googlevoice` in Info.plist (included).
- **Last attempt** — time + method used (web URL vs app scheme), so you
  can tell on the ship what actually happened.
- **In-app checklist** — the 5 steps above, tap Show in the app.

## 3. Apple + GitHub setup (same proven flow as Thanksgiving / Launch Window)

1. **Apple Developer portal** — create explicit App ID
   `studio.mikegyver.callmom` (no capabilities needed).
2. **App Store Connect** — New App, iOS only, name **Call Mom**,
   bundle `studio.mikegyver.callmom`, SKU `callmom-001`.
   Do this **before** the first signed workflow run — the workflow
   uploads by bundle ID and fails with no record, even if the App ID
   and secrets are in place.
3. **GitHub repo** — create empty `MikeGyver-SME/mikegyver-callmom`
   (no README / .gitignore). Add the 4 secrets you already use for
   your other apps: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
   `TEAM_ID`.
   Check a free Distribution certificate slot first — Apple allows 2
   per team. If both are taken, revoke only one (see the
   ios_app_widget_testflight checklist).
4. **Push (v1.0.1 update)** — save `callmom-v1.0.1.zip` +
   `push-callmom.ps1` in `E:\Downloads` (do NOT delete the existing
   `E:\Downloads\mikegyver-callmom` folder), then:
   `Unblock-File -Path "E:\Downloads\push-callmom.ps1"`
   `powershell -ExecutionPolicy Bypass -File E:\Downloads\push-callmom.ps1`
   It overlays the new zip onto the existing repo folder, commits,
   and tags `v1.0.1`.
5. **Run the workflow by hand** — GitHub → Actions →
   **Call Mom - Signed TestFlight** → Run workflow. A tag push does
   NOT start it (workflow_dispatch only).
6. **TestFlight** — after upload, check the build isn't at
   Missing Compliance. This app implements no encryption of its own
   (only standard HTTPS), so answer None of the algorithms mentioned
   above / `ITSAppUsesNonExemptEncryption = false` (already in
   Info.plist). Then add yourself to the internal test group for
   `studio.mikegyver.callmom` and install on your iPhone 18.

## 4. Files

- `CallMom/CallMomApp.swift` — @main entry
- `CallMom/ContentView.swift` — big-button UI, edit sheet, checklist, last-call log
- `CallMom/GoogleVoiceCaller.swift` — number normalising, official
  `voice.google.com` URL builder, `googlevoice://` fallback
- `CallMom/ConnectivityMonitor.swift` — NWPathMonitor Wi-Fi / cellular
- `CallMom/Info.plist` — `LSApplicationQueriesSchemes: googlevoice,
  gvconnect`, `ITSAppUsesNonExemptEncryption: false`, portrait only
- `project.yml` — XcodeGen, single target, manual signing
- `.github/workflows/testflight.yml` — signed TestFlight upload
- `push-callmom.ps1` — push + tag v1.0.1

## 5. If the handoff ever stops working

Google can change the Voice web URL or the app scheme without notice.
That is the known fragility of this approach, and why the app keeps
all three paths visible (web URL → Voice app → copy + manual dial).
If the web URL stops pre-dialling, use **Open Voice app** + **Copy
number** and dial by hand in Google Voice — the cruise Wi-Fi + 
Prefer Wi-Fi setting is what saves the roaming charge, not this app.
