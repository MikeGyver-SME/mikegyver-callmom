import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("momName") private var momName = "Mom"
    @AppStorage("momNumber") private var momNumber = ""
    @AppStorage("lastCallISO") private var lastCallISO = ""
    @AppStorage("lastCallMethod") private var lastCallMethod = ""

    @StateObject private var net = ConnectivityMonitor()
    @State private var showEdit = false
    @State private var showConfirmCall = false
    @State private var showChecklist = false
    @State private var showCopied = false
    @State private var showNoNumberAlert = false
    @State private var draftName = ""
    @State private var draftNumber = ""

    private var hasNumber: Bool { GoogleVoiceCaller.e164Digits(momNumber) != nil }
    private var displayNumber: String {
        hasNumber ? GoogleVoiceCaller.formatted(momNumber) : "No number saved yet"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cruise status
                    statusCard

                    // Big call button — one number, one tap.
                    VStack(spacing: 12) {
                        Button(action: { tapCall() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 64))
                                Text("Call \(momName)")
                                    .font(.system(size: 28, weight: .bold))
                                Text(displayNumber)
                                    .font(.system(size: 17))
                                    .opacity(0.85)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .foregroundStyle(.white)
                            .background(hasNumber ? Color.green : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                        .accessibilityLabel("Call \(momName) via Google Voice over Wi-Fi")
                        .disabled(!hasNumber)
                        .opacity(hasNumber ? 1 : 0.6)

                        Text("Opens Google Voice on Wi-Fi. No carrier minutes, no ship roaming — if Google Voice is set to “Prefer Wi-Fi and mobile data.”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        if !hasNumber {
                            Button("Add Mom's number") { openEdit() }
                                .buttonStyle(.borderedProminent)
                        }
                    }

                    // Secondary actions
                    HStack(spacing: 12) {
                        Button("Open Voice app") {
                            _ = GoogleVoiceCaller.openGoogleVoiceApp()
                            recordAttempt(method: GoogleVoiceCaller.Handoff.appScheme.rawValue)
                        }
                        .buttonStyle(.bordered)
                        Button("Copy number") {
                            UIPasteboard.general.string = GoogleVoiceCaller.formatted(momNumber)
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { showCopied = false }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!hasNumber)
                        Button("Edit") { openEdit() }
                            .buttonStyle(.bordered)
                    }
                    if showCopied {
                        Text("Copied — paste it into Google Voice if the handoff ever fails.")
                            .font(.footnote).foregroundStyle(.green)
                    }

                    // Last call
                    if !lastCallISO.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last attempt").font(.headline)
                            Text("\(lastCallISO) • \(lastCallMethod)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Pre-cruise checklist
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Before you sail").font(.headline)
                            Spacer()
                            Button(showChecklist ? "Hide" : "Show") { showChecklist.toggle() }
                                .font(.subheadline)
                        }
                        if showChecklist {
                            checklistRow("1.", "In Google Voice: Settings → Make and receive calls → Prefer Wi-Fi and mobile data. Not “Use carrier only.”")
                            checklistRow("2.", "On the ship: Airplane Mode ON, Wi-Fi ON, connect to ship Wi-Fi. Turn Data Roaming OFF.")
                            checklistRow("3.", "Test at home first: Airplane Mode + Wi-Fi on, call Mom. If it works there, it works on the ship's Wi-Fi.")
                            checklistRow("4.", "If the ship blocks VoIP, the call will fail to connect — try again on deck / near an access point, or in port on shore Wi-Fi.")
                            checklistRow("5.", "Google Voice can't call 911. For emergencies use the ship's phone / crew.")
                        } else {
                            Text("Tap Show for the 5-step ship checklist — do step 1 and 3 before you leave port.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("MikeGyver Studio • Number is stored only on this iPhone, never uploaded.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Call Mom")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { openEdit() }
                }
            }
            .sheet(isPresented: $showEdit) { editSheet }
            .confirmationDialog(
                "Call \(momName)?",
                isPresented: $showConfirmCall,
                titleVisibility: .visible
            ) {
                Button("Call via Google Voice") { doCall() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This leaves Call Mom and opens voice.google.com — Google Voice will dial \(displayNumber) over Wi-Fi/data with your Google Voice number as caller ID. Make sure you're on ship Wi-Fi with Airplane Mode on.")
            }
            .alert("Add Mom's number first", isPresented: $showNoNumberAlert) {
                Button("Add number") { openEdit() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter her US number (10 digits) — country code +1 is added automatically. International numbers need the full country code.")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: net.isWifi ? "wifi" : net.isConnected ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .foregroundStyle(net.isWifi ? .green : .orange)
                Text(net.label).font(.headline)
                Spacer()
                Text(GoogleVoiceCaller.isGoogleVoiceInstalled() ? "Voice app ✓" : "Voice app ?")
                    .font(.subheadline)
                    .foregroundStyle(GoogleVoiceCaller.isGoogleVoiceInstalled() ? .green : .orange)
            }
            if !net.isWifi {
                Text("For the ship: join ship Wi-Fi first. Cellular on a cruise ship is roaming.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !GoogleVoiceCaller.isGoogleVoiceInstalled() {
                Text("Google Voice app not detected — install it from the App Store and sign in before sailing. The web handoff still works in Safari.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func checklistRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num).bold()
            Text(text).font(.subheadline)
        }
    }

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("Who to call") {
                    TextField("Name", text: $draftName)
                        .textContentType(.name)
                    TextField("Phone number", text: $draftNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Text("US: 10 digits, e.g. 2815550147. +1 is added for you. International: include the country code, e.g. +44…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Save") {
                        momName = draftName.trimmingCharacters(in: .whitespaces).isEmpty ? "Mom" : draftName.trimmingCharacters(in: .whitespaces)
                        momNumber = draftNumber.trimmingCharacters(in: .whitespaces)
                        showEdit = false
                    }
                    .disabled(GoogleVoiceCaller.e164Digits(draftNumber) == nil)
                }
            }
            .navigationTitle("Edit contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEdit = false }
                }
            }
        }
    }

    private func openEdit() {
        draftName = momName
        draftNumber = momNumber
        showEdit = true
    }

    private func tapCall() {
        guard hasNumber else { showNoNumberAlert = true; return }
        showConfirmCall = true
    }

    private func doCall() {
        if GoogleVoiceCaller.callViaWeb(momNumber) {
            recordAttempt(method: GoogleVoiceCaller.Handoff.webURL.rawValue)
        }
    }

    private func recordAttempt(method: String) {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        lastCallISO = f.string(from: Date())
        lastCallMethod = method
    }
}

#Preview {
    ContentView()
}
