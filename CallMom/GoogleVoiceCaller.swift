import Foundation
import UIKit

/// Handoff to Google Voice for a single number — Mom.
///
/// ROOT CAUSE, v1.0.0 -> v1.0.1 (Mike, Nov 6, 2026):
/// v1.0.0 opened the official click-to-call URL in Safari:
///   https://voice.google.com/u/0/calls?a=nc,%2B<digits>
/// In Safari that is NOT the Voice app, so it does NOT use the app's
/// "Prefer Wi-Fi and mobile data" setting. Google's own help says:
///   "If you start a call from the phone app on your device instead of
///    the Voice app, the call uses minutes from your mobile phone plan.
///    To use Wi-Fi for a call, start the call from the Voice app."
///   (support.google.com/voice/answer/7649189)
/// And the web flow is a callback: "Google Voice will first call you
/// at the number specified in settings (your mobile usually) and then
/// they will make an attempt to call the Contact" — and on the web
/// "I will choose my iPhone, then it will call me and instantly connect
/// the call to the person I'm calling when I answer."
/// In Airplane Mode + Wi-Fi (the ship test, and the ship itself) that
/// callback to your cellphone can never arrive, so it just times out.
/// Directly in the Voice app it works, because the app IS in Prefer
/// Wi-Fi mode. The fix is to stay in the app.
///
/// v1.0.1 order:
/// 1. Universal link — open the same voice.google.com URL with
///    `.universalLinksOnly: true`. If Google Voice claims that domain,
///    iOS opens the URL IN the Voice app (not Safari), ideally with the
///    number pre-filled, using the app's Prefer Wi-Fi mode. If no app
///    handles it, the call returns false and we fall through — we never
///    silently land in Safari.
/// 2. googlevoice:// + auto-copy — open the Voice app itself and copy
///    the number to the clipboard first. There is NO documented
///    googlevoice://call form (only googlevoice:// and
///    googlevoice://voicemail are seen in the wild), so we do NOT claim
///    it pre-dials. If the app opens to its home screen, the user taps
///    Calls > keypad, long-presses to paste, and calls. That is 2 taps,
///    and it is a real in-app Wi-Fi call, not a callback.
/// 3. Web in Safari — kept ONLY as an explicit, labelled fallback
///    ("Web — carrier callback"). It will call your cellphone first.
///    Never the default.
///
/// We deliberately do NOT use tel: — tel: uses the carrier voice
/// network, which on a cruise ship is maritime roaming, not Wi-Fi.
enum GoogleVoiceCaller {

    enum Handoff: String {
        case appUniversalLink = "Voice app — universal link (in-app dial)"
        case appOpenCopy = "Voice app — opened, number copied, paste to dial"
        case webCallback = "Voice web in Safari — carrier callback"
        case manual = "Manual — copy + open app"
    }

    /// Strip to digits. 10 digits -> assume US +1. 11 digits starting 1 -> keep.
    /// Anything else -> keep as dialled (international numbers must include country code).
    static func digitsOnly(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    static func e164Digits(_ raw: String) -> String? {
        let d = digitsOnly(raw)
        if d.count == 10 { return "1" + d }
        if d.count == 11, d.hasPrefix("1") { return d }
        if d.count > 11 { return d } // international, already includes country code
        return nil
    }

    static func formatted(_ raw: String) -> String {
        guard let d = e164Digits(raw) else { return raw }
        if d.count == 11, d.hasPrefix("1") {
            let a = d.dropFirst()
            return "+1 (\(a.prefix(3))) \(a.dropFirst(3).prefix(3))-\(a.dropFirst(6))"
        }
        return "+" + d
    }

    /// Official Google Voice click-to-call URL (documented at
    /// support.google.com/voice/answer/3379129). Useful as a universal
    /// link into the app, and as a web URL — but NOT as a Safari default,
    /// for the callback reason above.
    static func webCallURL(for raw: String) -> URL? {
        guard let d = e164Digits(raw) else { return nil }
        return URL(string: "https://voice.google.com/u/0/calls?a=nc,%2B\(d)")
    }

    static var googleVoiceAppURL: URL? { URL(string: "googlevoice://") }
    static var googleVoiceVoicemailURL: URL? { URL(string: "googlevoice://voicemail") }

    static func isGoogleVoiceInstalled() -> Bool {
        guard let url = googleVoiceAppURL else { return false }
        // Requires LSApplicationQueriesSchemes = googlevoice in Info.plist.
        // Without it canOpenURL always returns false.
        return UIApplication.shared.canOpenURL(url)
    }

    /// Copy the diallable number (+1xxxxxxxxxx) for pasting into the
    /// Voice app keypad. Returns false if there is no valid number.
    @discardableResult
    static func copyNumber(_ raw: String) -> Bool {
        guard let d = e164Digits(raw) else { return false }
        UIPasteboard.general.string = "+" + d
        return true
    }

    /// Primary call in v1.0.1: stay in the Voice app.
    /// 1) Try the voice.google.com URL as a universal link (app only).
    /// 2) Otherwise open googlevoice:// with the number already copied.
    /// 3) Otherwise (app not installed) open the web URL in Safari and
    ///    report it honestly as a carrier callback.
    /// Completion is always called, on the main thread, with the method used.
    static func callViaApp(_ raw: String, completion: @escaping (Handoff) -> Void) {
        guard let url = webCallURL(for: raw) else { return }
        _ = copyNumber(raw)

        // Step 1: universal link, app only — no Safari fallback.
        UIApplication.shared.open(
            url,
            options: [.universalLinksOnly: true]
        ) { success in
            DispatchQueue.main.async {
                if success {
                    completion(.appUniversalLink)
                    return
                }
                // Step 2: open the app itself, number already on clipboard.
                if let appURL = googleVoiceAppURL,
                   UIApplication.shared.canOpenURL(appURL) {
                    UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
                    completion(.appOpenCopy)
                    return
                }
                // Step 3: no Voice app — Safari web, carrier callback.
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                completion(.webCallback)
            }
        }
    }

    /// Explicit Safari web handoff. Label this in the UI as a carrier
    /// callback: Google Voice will call your cellphone first, then connect.
    /// Do NOT use as the default — it times out in Airplane Mode + Wi-Fi.
    @discardableResult
    static func callViaWebCallback(_ raw: String) -> Bool {
        guard let url = webCallURL(for: raw) else { return false }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    @discardableResult
    static func openGoogleVoiceApp() -> Bool {
        guard let url = googleVoiceAppURL else { return false }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return true
        }
        // App not installed — fall back to the Voice website.
        if let web = URL(string: "https://voice.google.com") {
            UIApplication.shared.open(web, options: [:], completionHandler: nil)
            return true
        }
        return false
    }
}
