import SwiftUI
import LocalAuthentication
import Combine

// MARK: - 1. Domain Models & Enums

enum UserDemographic: String, CaseIterable, Identifiable {
    case adult = "Adult"
    case senior = "Senior"
    case child = "Child"
    var id: String { rawValue }
}

enum DevicePosture: String, CaseIterable, Identifiable {
    case stationary = "Desk / Quiet"
    case walking = "Walking / Mobile"
    case vehicle = "In Vehicle"
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .stationary: return "deskclock.fill"
        case .walking: return "figure.walk"
        case .vehicle: return "car.fill"
        }
    }
}

enum PrivacyRiskLevel: String {
    case low = "Low Risk"
    case elevated = "Elevated Risk"
    case critical = "High Risk (PII Detected)"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .elevated: return .orange
        case .critical: return .red
        }
    }
}

enum AppActionIntent: Equatable {
    case sendPayment(amount: Double, recipient: String, riskFactors: [String])
    case generalInquiry(text: String)
    case none
}

// MARK: - 2. Self-Healing UI Engine

final class SelfHealingEngine: ObservableObject {
    @Published var isGlitchActive: Bool = false
    @Published var healCount: Int = 0
    @Published var isHealing: Bool = false
    @Published var statusMessage: String = "UI Health Nominal (100%)"
    
    func injectAnomaly() {
        isGlitchActive = true
        statusMessage = "ALERT: UI Degraded (Touch target clipped, low contrast)"
    }
    
    func triggerAutoHeal() {
        guard isGlitchActive else { return }
        isHealing = true
        statusMessage = "Self-Healing Engine evaluating layout constraints..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isGlitchActive = false
            self.isHealing = false
            self.healCount += 1
            self.statusMessage = "UI Restored & Self-Healed (Auto-repair #\(self.healCount))"
        }
    }
}

// MARK: - 3. Edge Intelligence Broker (SLM + PII Scrubbing + Privacy Radar)

final class EdgeIntelligenceBroker: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var lastSanitizedInput: String = ""
    @Published var redactedTokens: [String] = []
    @Published var privacyRisk: PrivacyRiskLevel = .low
    
    func resolveIntent(from rawPrompt: String) async -> AppActionIntent {
        await MainActor.run { isProcessing = true }
        
        // 1. Scrub PII
        let (sanitized, foundTokens) = sanitizePII(rawPrompt)
        
        await MainActor.run {
            self.lastSanitizedInput = sanitized
            self.redactedTokens = foundTokens
            self.privacyRisk = foundTokens.isEmpty ? .low : .critical
        }
        
        // 2. Simulate NPU inference delay
        try? await Task.sleep(nanoseconds: 250_000_000)
        await MainActor.run { isProcessing = false }
        
        // 3. Schema Parsing & Risk Assessment
        let lower = sanitized.lowercased()
        if lower.contains("send") || lower.contains("transfer") || lower.contains("pay") {
            let amount = extractAmount(from: lower) ?? 50.0
            let recipient = extractRecipient(from: rawPrompt) ?? "Unknown Payee"
            
            var risks: [String] = []
            if amount >= 500 { risks.append("High Amount: $\(Int(amount))") }
            if !foundTokens.isEmpty { risks.append("Redacted Sensitive Info (\(foundTokens.count) item(s))") }
            if recipient == "Unknown Payee" { risks.append("Unverified Recipient") }
            
            return .sendPayment(amount: amount, recipient: recipient, riskFactors: risks)
        }
        
        return .generalInquiry(text: sanitized)
    }
    
    private func sanitizePII(_ text: String) -> (String, [String]) {
        var clean = text
        var tokens: [String] = []
        
        // Credit Card
        let ccPattern = #"\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b"#
        if let regex = try? NSRegularExpression(pattern: ccPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for m in matches {
                if let r = Range(m.range, in: text) { tokens.append(String(text[r])) }
            }
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "[CARD_REDACTED]")
        }
        
        // SSN
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        if let regex = try? NSRegularExpression(pattern: ssnPattern) {
            let matches = regex.matches(in: clean, range: NSRange(clean.startIndex..., in: clean))
            for m in matches {
                if let r = Range(m.range, in: clean) { tokens.append(String(clean[r])) }
            }
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "[SSN_REDACTED]")
        }
        
        // Phone
        let phonePattern = #"\b\d{10}\b"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: clean, range: NSRange(clean.startIndex..., in: clean))
            for m in matches {
                if let r = Range(m.range, in: clean) { tokens.append(String(clean[r])) }
            }
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "[PHONE_REDACTED]")
        }
        
        return (clean, tokens)
    }
    
    private func extractAmount(from text: String) -> Double? {
        let pattern = #"\$?([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }
    
    private func extractRecipient(from text: String) -> String? {
        let tokens = text.components(separatedBy: " ")
        if let idx = tokens.firstIndex(where: { $0.lowercased() == "to" }), idx + 1 < tokens.count {
            return tokens[idx + 1].capitalized
        }
        return nil
    }
}

// MARK: - 4. Adaptive Layout & Palette Engine

struct LayoutConfig {
    let minTouchTarget: CGFloat
    let fontOffset: CGFloat
    let animDuration: Double
    let animDamping: Double
    
    static func config(for demographic: UserDemographic, posture: DevicePosture, isGlitched: Bool) -> LayoutConfig {
        if isGlitched {
            // Degraded state for simulation
            return .init(minTouchTarget: 28, fontOffset: -2, animDuration: 0.05, animDamping: 0.4)
        }
        
        var baseTarget: CGFloat = 44
        var baseFont: CGFloat = 0
        var duration: Double = 0.25
        var damping: Double = 0.85
        
        switch demographic {
        case .senior:
            baseTarget = 64
            baseFont = 4
            duration = 0.15
            damping = 1.0
        case .child:
            baseTarget = 52
            baseFont = 2
            duration = 0.35
            damping = 0.7
        case .adult:
            baseTarget = 44
            baseFont = 0
        }
        
        switch posture {
        case .walking:
            baseTarget += 10
            baseFont += 1
            damping = 0.95
        case .vehicle:
            baseTarget += 16
            baseFont += 3
            damping = 1.0
        case .stationary:
            break
        }
        
        return .init(minTouchTarget: baseTarget, fontOffset: baseFont, animDuration: duration, animDamping: damping)
    }
}

struct AdaptivePalette {
    let bg: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    
    static func resolve(isDark: Bool, lux: Double, isSenior: Bool, isGlitched: Bool) -> AdaptivePalette {
        if isGlitched {
            return AdaptivePalette(
                bg: Color(red: 0.15, green: 0.1, blue: 0.1),
                surface: Color(red: 0.25, green: 0.15, blue: 0.15),
                textPrimary: .red,
                textSecondary: Color.red.opacity(0.7),
                accent: .red
            )
        }
        
        let isNightComfort = lux < 15.0
        
        if isDark {
            return AdaptivePalette(
                bg: isNightComfort ? Color(red: 0.08, green: 0.07, blue: 0.05) : .black,
                surface: Color(white: 0.15),
                textPrimary: isSenior ? .white : Color(white: 0.92),
                textSecondary: Color(white: 0.65),
                accent: isNightComfort ? .orange : .blue
            )
        } else {
            return AdaptivePalette(
                bg: isNightComfort ? Color(red: 0.98, green: 0.96, blue: 0.91) : Color(white: 0.97),
                surface: .white,
                textPrimary: isSenior ? .black : Color(white: 0.12),
                textSecondary: Color(white: 0.4),
                accent: isNightComfort ? Color.brown : Color.blue
            )
        }
    }
}

// MARK: - 5. Biometric Gate

final class BiometricGate {
    static func verify(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return true
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}

// MARK: - 6. Voice Waveform Simulator View

struct VoiceWaveformView: View {
    let accentColor: Color
    @State private var phase: Double = 0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor)
                    .frame(width: 4, height: CGFloat(10 + 20 * sin(phase + Double(index) * 0.5)))
            }
        }
        .frame(height: 34)
        .onReceive(timer) { _ in
            phase += 0.4
        }
    }
}

// MARK: - 7. Main Prototype View

struct ContentView: View {
    @StateObject private var broker = EdgeIntelligenceBroker()
    @StateObject private var healer = SelfHealingEngine()
    
    // Developer & Signal Controls
    @State private var selectedDemographic: UserDemographic = .adult
    @State private var selectedPosture: DevicePosture = .stationary
    @State private var simulatedLux: Double = 100.0
    @State private var isDarkMode: Bool = false
    @State private var isListeningVoice: Bool = false
    
    // Inputs & Feedback
    @State private var inputPrompt: String = "Send $2500 to Alice card 4111-2222-3333-4444 ssn 123-45-6789"
    @State private var appFeedbackText: String = "Ready for instructions."
    
    // Modal State
    @State private var showPauseModal: Bool = false
    @State private var pendingTransaction: (amount: Double, recipient: String, risks: [String])? = nil
    
    var layout: LayoutConfig {
        LayoutConfig.config(for: selectedDemographic, posture: selectedPosture, isGlitched: healer.isGlitchActive)
    }
    
    var palette: AdaptivePalette {
        AdaptivePalette.resolve(isDark: isDarkMode, lux: simulatedLux, isSenior: selectedDemographic == .senior, isGlitched: healer.isGlitchActive)
    }
    
    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    selfHealingBannerCard
                    environmentControlsCard
                    agentInputCard
                    smartSurfacePreviewCard
                }
                .padding()
            }
            .animation(.spring(response: layout.animDuration, dampingFraction: layout.animDamping), value: selectedDemographic)
            .animation(.spring(response: layout.animDuration, dampingFraction: layout.animDamping), value: selectedPosture)
            .animation(.easeInOut(duration: 0.3), value: simulatedLux)
            .animation(.easeInOut(duration: 0.3), value: isDarkMode)
            .animation(.easeInOut(duration: 0.3), value: healer.isGlitchActive)
            
            // Full Screen Cognitive Interceptor
            if showPauseModal, let tx = pendingTransaction {
                EnhancedPauseInterceptorView(
                    amount: tx.amount,
                    recipient: tx.recipient,
                    riskFactors: tx.risks,
                    palette: palette,
                    onCancel: {
                        showPauseModal = false
                        pendingTransaction = nil
                        appFeedbackText = "Transaction cancelled by user during cognitive cooldown."
                    },
                    onCooldownComplete: {
                        completeTransactionWithBiometrics(tx)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(10)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Next-Gen Mobile Core")
                    .font(.system(size: 20 + layout.fontOffset, weight: .bold))
                    .foregroundColor(palette.textPrimary)
                Text("Self-Healing UI & Edge Intelligence Engine")
                    .font(.system(size: 12 + layout.fontOffset))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(broker.isProcessing ? Color.orange : (healer.isGlitchActive ? Color.red : Color.green))
                        .frame(width: 10, height: 10)
                    Text(healer.isGlitchActive ? "Degraded" : (broker.isProcessing ? "Inferring" : "Nominal"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.textSecondary)
                }
                
                Text(broker.privacyRisk.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(broker.privacyRisk.color)
            }
        }
    }
    
    private var selfHealingBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Self-Healing UI Diagnostics", systemImage: "bandage.fill")
                    .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                    .foregroundColor(healer.isGlitchActive ? .red : palette.textPrimary)
                Spacer()
                Text("Repairs: \(healer.healCount)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.bg)
                    .cornerRadius(8)
                    .foregroundColor(palette.textSecondary)
            }
            
            Text(healer.statusMessage)
                .font(.system(size: 12 + layout.fontOffset))
                .foregroundColor(palette.textSecondary)
            
            HStack(spacing: 12) {
                Button(action: { healer.injectAnomaly() }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Simulate Glitch")
                    }
                    .font(.system(size: 12 + layout.fontOffset, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                
                Button(action: { healer.triggerAutoHeal() }) {
                    HStack {
                        if healer.isHealing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Auto-Heal UI")
                        }
                    }
                    .font(.system(size: 12 + layout.fontOffset, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(healer.isGlitchActive ? Color.green : palette.accent.opacity(0.3))
                    .foregroundColor(healer.isGlitchActive ? .white : palette.textPrimary)
                    .cornerRadius(10)
                }
                .disabled(!healer.isGlitchActive && !healer.isHealing)
            }
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(healer.isGlitchActive ? Color.red.opacity(0.6) : Color.clear, lineWidth: 2)
        )
    }
    
    private var environmentControlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ambient Signals & Device Posture", systemImage: "slider.horizontal.3")
                .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                .foregroundColor(palette.textPrimary)
            
            // 1. Demographic picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Demographic")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                Picker("Demographic", selection: $selectedDemographic) {
                    ForEach(UserDemographic.allCases) { demo in
                        Text(demo.rawValue).tag(demo)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 2. Posture picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Posture Mode")
                    .font(.caption)
                    .foregroundColor(palette.textSecondary)
                Picker("Posture", selection: $selectedPosture) {
                    ForEach(DevicePosture.allCases) { posture in
                        Label(posture.rawValue, systemImage: posture.icon).tag(posture)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 3. Ambient Lux slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Ambient Light (Lux): \(Int(simulatedLux)) lm")
                    Spacer()
                    Text(simulatedLux < 15.0 ? "Sepia Bedtime Comfort" : "Standard Daylight")
                        .foregroundColor(palette.accent)
                }
                .font(.system(size: 12 + layout.fontOffset))
                .foregroundColor(palette.textSecondary)
                
                Slider(value: $simulatedLux, in: 0...200, step: 5)
            }
            
            HStack {
                Toggle("Dark Mode", isOn: $isDarkMode)
                    .font(.system(size: 14 + layout.fontOffset))
                    .foregroundColor(palette.textPrimary)
            }
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(16)
    }
    
    private var agentInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Intent Interface & Voice Audio", systemImage: "sparkles")
                    .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                    .foregroundColor(palette.textPrimary)
                Spacer()
                
                Button(action: { isListeningVoice.toggle() }) {
                    Image(systemName: isListeningVoice ? "mic.fill" : "mic.slash")
                        .foregroundColor(isListeningVoice ? .red : palette.accent)
                        .padding(6)
                        .background(palette.bg)
                        .clipShape(Circle())
                }
            }
            
            if isListeningVoice {
                HStack {
                    Text("Voice Edge Listener Active:")
                        .font(.caption)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    VoiceWaveformView(accentColor: palette.accent)
                }
                .padding(8)
                .background(palette.bg)
                .cornerRadius(10)
            }
            
            TextField("Express intent prompt...", text: $inputPrompt)
                .font(.system(size: 14 + layout.fontOffset))
                .padding(12)
                .background(palette.bg)
                .cornerRadius(10)
                .foregroundColor(palette.textPrimary)
            
            // Preset Intent Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton("Send $2500 Card PII", prompt: "Send $2500 to Alice card 4111-2222-3333-4444 ssn 123-45-6789")
                    presetButton("Pay $50 Dinner", prompt: "Transfer $50 to Bob for dinner")
                    presetButton("General Inquiry", prompt: "What is my current account summary?")
                }
            }
            
            Button(action: executeIntent) {
                HStack {
                    if broker.isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Process Intent")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: layout.minTouchTarget)
                .background(palette.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.system(size: 15 + layout.fontOffset, weight: .semibold))
            }
            
            // Privacy Radar Audit Output
            if !broker.lastSanitizedInput.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("PRIVACY RADAR OUTPUT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.textSecondary)
                        Spacer()
                        Text(broker.privacyRisk.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(broker.privacyRisk.color)
                    }
                    
                    Text(broker.lastSanitizedInput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(palette.textPrimary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.bg)
                        .cornerRadius(8)
                    
                    if !broker.redactedTokens.isEmpty {
                        Text("Scrubbed Tokens: \(broker.redactedTokens.joined(separator: ", "))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(16)
    }
    
    private func presetButton(_ label: String, prompt: String) -> some View {
        Button(action: { inputPrompt = prompt }) {
            Text(label)
                .font(.system(size: 11 + layout.fontOffset, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(palette.bg)
                .foregroundColor(palette.accent)
                .cornerRadius(8)
        }
    }
    
    private var smartSurfacePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dynamic Surface & Action Ledger", systemImage: "macwindow.on.rectangle")
                .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                .foregroundColor(palette.textPrimary)
            
            Text(appFeedbackText)
                .font(.system(size: 13 + layout.fontOffset))
                .foregroundColor(palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(palette.bg)
                .cornerRadius(10)
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Logic Handling
    
    private func executeIntent() {
        Task {
            let intent = await broker.resolveIntent(from: inputPrompt)
            
            await MainActor.run {
                switch intent {
                case .sendPayment(let amount, let recipient, let riskFactors):
                    if amount >= 500 || !riskFactors.isEmpty {
                        self.pendingTransaction = (amount, recipient, riskFactors)
                        self.showPauseModal = true
                    } else {
                        self.appFeedbackText = "Executed low-risk payment: $\(amount) to \(recipient)."
                    }
                case .generalInquiry(let text):
                    self.appFeedbackText = "Broker handled query: '\(text)'"
                case .none:
                    self.appFeedbackText = "No actionable intent mapped."
                }
            }
        }
    }
    
    private func completeTransactionWithBiometrics(_ tx: (amount: Double, recipient: String, risks: [String])) {
        Task {
            let verified = await BiometricGate.verify(reason: "Authorize high-stakes transfer of $\(tx.amount)")
            await MainActor.run {
                self.showPauseModal = false
                self.pendingTransaction = nil
                if verified {
                    self.appFeedbackText = "SUCCESS: Biometrically authenticated & transferred $\(tx.amount) to \(tx.recipient)."
                } else {
                    self.appFeedbackText = "ALERT: Biometric verification failed or was cancelled."
                }
            }
        }
    }
}

// MARK: - 8. Enhanced Cognitive "Pause" Interceptor Modal

struct EnhancedPauseInterceptorView: View {
    let amount: Double
    let recipient: String
    let riskFactors: [String]
    let palette: AdaptivePalette
    let onCancel: () -> Void
    let onCooldownComplete: () -> Void
    
    @State private var timeRemaining: Int = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Warning Icon + Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(10 - timeRemaining) / 10.0)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timeRemaining)
                    
                    Image(systemName: "shield.exclamationmark.fill")
                        .resizable()
                        .frame(width: 38, height: 42)
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 6) {
                    Text("Take a Breath")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Attempting high-value transfer of $\(String(format: "%.2f", amount)) to \(recipient).")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Risk Factors List
                if !riskFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RISK ANALYTICS TRIGGERED:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        
                        ForEach(riskFactors, id: \.self) { factor in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(factor)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                
                VStack(spacing: 4) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Seconds required cooldown before Face ID")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                VStack(spacing: 10) {
                    if timeRemaining == 0 {
                        Button(action: onCooldownComplete) {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Authorize with Face ID")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: onCancel) {
                        Text("Cancel Transfer")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(Color(white: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 20)
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
