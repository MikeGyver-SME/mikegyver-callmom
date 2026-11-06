import Foundation
import UIKit

/// Handoff to Google Voice for a single number — Mom.
///
/// Why this order matters (verified Nov 5, 2026):
/// 1. Official click-to-call URL — Google documents it:
///    https://voice.google.com/u/0/calls?a=nc,%2B<digits>
///    "In the address bar, enter https://voice.google.com/u/0/calls?a=nc,%2Bphonenumber.
///    Make sure to replace phonenumber with the number you want to call without hyphens."
///    (support.google.com/voice/answer/3379129)
///    This is the reliable path. It opens Safari / Voice web signed in as you,
///    with your Google Voice number as caller ID, over Wi-Fi/data.
/// 2. googlevoice:// — undocumented scheme, only opens the app.
///    googlevoice://voicemail is seen in the wild; there is NO documented
///    googlevoice://call?number= form. We try the app only as a fallback,
///    and we never claim it pre-dials the number.
/// 3. Manual — copy the number, open Google Voice, dial by hand.
///
/// We deliberately do NOT use tel: as the primary path. tel: uses the
/// carrier voice network. On a cruise ship that is roaming / maritime
/// cellular — expensive, and not Wi-Fi. Google Voice in
/// "Prefer Wi-Fi and mobile data" mode is the Wi-Fi path.
enum GoogleVoiceCaller {

    enum Handoff: String {
        case webURL = "Google Voice web (voice.google.com)"
        case appScheme = "Google Voice app (googlevoice://)"
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

    /// Official Google Voice click-to-call URL.
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

    /// Primary call. Opens the official Voice web URL. Returns the method used.
    /// Callers should show the "you are leaving Call Mom" note first — the
    /// call itself happens in Safari / Google Voice, not in this app.
    @discardableResult
    static func callViaWeb(_ raw: String) -> Bool {
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
