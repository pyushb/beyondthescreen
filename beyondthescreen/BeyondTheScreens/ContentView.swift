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
    case critical = "High Risk (PII Scrubbed)"
    
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

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: Sender
    let text: String
    let timestamp: Date
    let isCorrected: Bool
    
    enum Sender {
        case user
        case ai
    }
}

struct ChainOfThoughtStep: Identifiable {
    let id = UUID()
    let timestamp: String
    let phase: String
    let detail: String
    let icon: String
}

struct CorrectionSuggestion {
    let originalText: String
    let correctedText: String
    let explanation: String
    let detectedTypos: [String]
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

// MARK: - 3. Edge Intelligence Broker & Assistive Correction Engine

final class EdgeIntelligenceBroker: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var lastSanitizedInput: String = ""
    @Published var redactedTokens: [String] = []
    @Published var privacyRisk: PrivacyRiskLevel = .low
    @Published var cotSteps: [ChainOfThoughtStep] = []
    @Published var streamedText: String = ""
    @Published var generatedJSON: String = ""
    @Published var messages: [ChatMessage] = [
        ChatMessage(sender: .ai, text: "Hello! I am your On-Device AI Assistant. How can I help you today?", timestamp: Date(), isCorrected: false)
    ]
    
    // Telemetry Metrics
    @Published var npuLoad: Int = 18
    @Published var tokensPerSec: Double = 46.8
    @Published var ttftMs: Int = 12
    @Published var ramUsageMB: Int = 1380
    
    func analyzeTypoAndCorrection(prompt: String) -> CorrectionSuggestion? {
        let lower = prompt.lowercased()
        var typos: [String] = []
        var corrected = prompt
        
        if lower.contains("snd") || lower.contains("sned") {
            typos.append("'snd' -> 'Send'")
            corrected = corrected.replacingOccurrences(of: "snd", with: "Send", options: .caseInsensitive)
            corrected = corrected.replacingOccurrences(of: "sned", with: "Send", options: .caseInsensitive)
        }
        if lower.contains("dolars") || lower.contains("doller") {
            typos.append("'dolars' -> '$'")
            corrected = corrected.replacingOccurrences(of: "dolars", with: "", options: .caseInsensitive)
            corrected = corrected.replacingOccurrences(of: "doller", with: "", options: .caseInsensitive)
        }
        if lower.contains("alic") {
            typos.append("'alic' -> 'Alice'")
            corrected = corrected.replacingOccurrences(of: "alic", with: "Alice", options: .caseInsensitive)
        }
        if lower.contains("dinenr") {
            typos.append("'dinenr' -> 'dinner'")
            corrected = corrected.replacingOccurrences(of: "dinenr", with: "dinner", options: .caseInsensitive)
        }
        if lower.contains("wat") {
            typos.append("'wat' -> 'What'")
            corrected = corrected.replacingOccurrences(of: "wat", with: "What", options: .caseInsensitive)
        }
        
        guard !typos.isEmpty else { return nil }
        
        let explanation = "On-Device AI corrected spelling errors (\(typos.joined(separator: ", "))) to ensure accurate intent execution."
        return CorrectionSuggestion(originalText: prompt, correctedText: corrected, explanation: explanation, detectedTypos: typos)
    }
    
    func resolveIntent(from rawPrompt: String, wasCorrected: Bool = false) async -> AppActionIntent {
        await MainActor.run {
            self.isProcessing = true
            self.npuLoad = Int.random(in: 76...94)
            self.cotSteps = []
            self.streamedText = ""
            self.generatedJSON = ""
            self.messages.append(ChatMessage(sender: .user, text: rawPrompt, timestamp: Date(), isCorrected: wasCorrected))
        }
        
        // CoT Step 1: PII Scrubbing
        await addCoT(step: ChainOfThoughtStep(timestamp: "00:01ms", phase: "PII Scrubbing", detail: "Scrubbing credit card, SSN & phone entities locally...", icon: "shield.checkerboard"))
        let (sanitized, foundTokens) = sanitizePII(rawPrompt)
        try? await Task.sleep(nanoseconds: 120_000_000)
        
        await MainActor.run {
            self.lastSanitizedInput = sanitized
            self.redactedTokens = foundTokens
            self.privacyRisk = foundTokens.isEmpty ? .low : .critical
        }
        
        // CoT Step 2: Embedding Semantic Search
        await addCoT(step: ChainOfThoughtStep(timestamp: "00:05ms", phase: "Vector Embeddings", detail: "Cosine similarity search matched intent: Payment Transfer (score: 0.96)", icon: "cpu"))
        try? await Task.sleep(nanoseconds: 120_000_000)
        
        // CoT Step 3: Local Safety & Behavioral Heuristics
        let lower = sanitized.lowercased()
        let isPayment = lower.contains("send") || lower.contains("transfer") || lower.contains("pay")
        let amount = extractAmount(from: lower) ?? 50.0
        let recipient = extractRecipient(from: rawPrompt) ?? "Unknown Payee"
        
        var risks: [String] = []
        if amount >= 500 { risks.append("High Amount: $\(Int(amount))") }
        if !foundTokens.isEmpty { risks.append("Redacted Sensitive PII (\(foundTokens.count) item(s))") }
        if recipient == "Unknown Payee" { risks.append("Unverified Recipient") }
        
        await addCoT(step: ChainOfThoughtStep(timestamp: "00:09ms", phase: "Safety Heuristics", detail: isPayment ? "Payment policy triggered (\(risks.count) risk flags)" : "General query policy approved", icon: "checkmark.shield"))
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // CoT Step 4: Emitting Structured JSON
        let jsonOutput = """
        {
          "model": "AppleIntelligence-SLM-3B-Local",
          "intent": "\(isPayment ? "sendPayment" : "generalInquiry")",
          "parameters": {
            "amount": \(amount),
            "recipient": "\(recipient)",
            "privacyRisk": "\(foundTokens.isEmpty ? "low" : "critical")"
          },
          "offlineVerified": true
        }
        """
        
        await MainActor.run {
            self.generatedJSON = jsonOutput
        }
        
        await addCoT(step: ChainOfThoughtStep(timestamp: "00:14ms", phase: "SLM Structured JSON", detail: "Emitted function call schema to iOS App Executor", icon: "curlybraces"))
        
        let aiResponse = isPayment ?
            "On-Device AI processed payment intent: Send $\(Int(amount)) to \(recipient). PII scrubbed locally." :
            "On-Device AI processed query: '\(sanitized)'"
        
        for char in aiResponse {
            await MainActor.run { self.streamedText.append(char) }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }
        
        await MainActor.run {
            self.messages.append(ChatMessage(sender: .ai, text: aiResponse, timestamp: Date(), isCorrected: false))
            self.isProcessing = false
            self.npuLoad = 18
        }
        
        if isPayment {
            return .sendPayment(amount: amount, recipient: recipient, riskFactors: risks)
        } else {
            return .generalInquiry(text: sanitized)
        }
    }
    
    @MainActor
    private func addCoT(step: ChainOfThoughtStep) {
        cotSteps.append(step)
    }
    
    private func sanitizePII(_ text: String) -> (String, [String]) {
        var clean = text
        var tokens: [String] = []
        
        let ccPattern = #"\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b"#
        if let regex = try? NSRegularExpression(pattern: ccPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for m in matches {
                if let r = Range(m.range, in: text) { tokens.append(String(text[r])) }
            }
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "[CARD_REDACTED]")
        }
        
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        if let regex = try? NSRegularExpression(pattern: ssnPattern) {
            let matches = regex.matches(in: clean, range: NSRange(clean.startIndex..., in: clean))
            for m in matches {
                if let r = Range(m.range, in: clean) { tokens.append(String(clean[r])) }
            }
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "[SSN_REDACTED]")
        }
        
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

// MARK: - 4. Apple Intelligence Style Glowing Screen-Edge "Neural Aura"

struct NeuralAuraView: View {
    let isActive: Bool
    @State private var rotationAngle: Double = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 48)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .purple, .pink, .orange, .yellow, .cyan]),
                            center: .center,
                            angle: .degrees(rotationAngle)
                        ),
                        lineWidth: 10
                    )
                    .blur(radius: 12)
                    .opacity(0.85)
                    .ignoresSafeArea()
                
                RoundedRectangle(cornerRadius: 48)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .purple, .pink, .orange, .yellow, .cyan]),
                            center: .center,
                            angle: .degrees(rotationAngle)
                        ),
                        lineWidth: 4
                    )
                    .opacity(0.95)
                    .ignoresSafeArea()
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                rotationAngle += 4
                if rotationAngle >= 360 { rotationAngle = 0 }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

// MARK: - 5. Adaptive Layout & Palette Engine

struct LayoutConfig {
    let minTouchTarget: CGFloat
    let fontOffset: CGFloat
    let animDuration: Double
    let animDamping: Double
    
    static func config(for demographic: UserDemographic, posture: DevicePosture, isGlitched: Bool) -> LayoutConfig {
        if isGlitched {
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

// MARK: - 6. Biometric Gate

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

// MARK: - 7. Voice Waveform Simulator View

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

// MARK: - 8. Main Root View (TabView Architecture)

struct ContentView: View {
    @StateObject private var broker = EdgeIntelligenceBroker()
    @StateObject private var healer = SelfHealingEngine()
    @State private var selectedTab: Int = 1 // 0: Core Engine, 1: Chat
    @FocusState private var isInputFocused: Bool
    
    // Developer & Signal Controls
    @State private var selectedDemographic: UserDemographic = .adult
    @State private var selectedPosture: DevicePosture = .stationary
    @State private var simulatedLux: Double = 100.0
    @State private var isDarkMode: Bool = false
    @State private var isListeningVoice: Bool = false
    @State private var forceNeuralAura: Bool = false
    @State private var showCotTrace: Bool = true
    
    // Inputs & Feedback
    @State private var inputPrompt: String = "Snd 2500 dolars to alic card 4111-2222-3333-4444 ssn 123-45-6789"
    @State private var appFeedbackText: String = "Ready for instructions."
    
    // Modals State
    @State private var showPauseModal: Bool = false
    @State private var pendingTransaction: (amount: Double, recipient: String, risks: [String])? = nil
    @State private var pendingCorrection: CorrectionSuggestion? = nil
    @State private var showCorrectionModal: Bool = false
    
    var layout: LayoutConfig {
        LayoutConfig.config(for: selectedDemographic, posture: selectedPosture, isGlitched: healer.isGlitchActive)
    }
    
    var palette: AdaptivePalette {
        AdaptivePalette.resolve(isDark: isDarkMode, lux: simulatedLux, isSenior: selectedDemographic == .senior, isGlitched: healer.isGlitchActive)
    }
    
    var isTyping: Bool {
        isInputFocused && !inputPrompt.isEmpty
    }
    
    var isAuraActive: Bool {
        broker.isProcessing || isListeningVoice || forceNeuralAura || isTyping
    }
    
    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            
            // Screen-Edge Neural Aura Layer
            NeuralAuraView(isActive: isAuraActive)
            
            TabView(selection: $selectedTab) {
                CoreEngineTab(
                    broker: broker,
                    healer: healer,
                    selectedDemographic: $selectedDemographic,
                    selectedPosture: $selectedPosture,
                    simulatedLux: $simulatedLux,
                    isDarkMode: $isDarkMode,
                    forceNeuralAura: $forceNeuralAura,
                    layout: layout,
                    palette: palette
                )
                .tabItem {
                    Label("Core Engine", systemImage: "cpu.fill")
                }
                .tag(0)
                
                ChatTab(
                    broker: broker,
                    inputPrompt: $inputPrompt,
                    isListeningVoice: $isListeningVoice,
                    showCotTrace: $showCotTrace,
                    isInputFocused: $isInputFocused,
                    layout: layout,
                    palette: palette,
                    onSendTap: handleSendIntentTap
                )
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)
            }
            .accentColor(palette.accent)
            
            // AI Smart Typo Correction Modal
            if showCorrectionModal, let correction = pendingCorrection {
                SmartCorrectionModalView(
                    suggestion: correction,
                    palette: palette,
                    onAccept: {
                        self.inputPrompt = correction.correctedText
                        self.showCorrectionModal = false
                        self.pendingCorrection = nil
                        self.executeIntentInternal(promptToRun: correction.correctedText, wasCorrected: true)
                    },
                    onRejectOriginal: {
                        self.showCorrectionModal = false
                        self.pendingCorrection = nil
                        self.executeIntentInternal(promptToRun: correction.originalText, wasCorrected: false)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(15)
            }
            
            // Full Screen Cognitive Interceptor Modal
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
                .zIndex(20)
            }
        }
    }
    
    // MARK: - Logic Handling
    
    private func handleSendIntentTap() {
        isInputFocused = false
        if let correction = broker.analyzeTypoAndCorrection(prompt: inputPrompt) {
            self.pendingCorrection = correction
            self.showCorrectionModal = true
        } else {
            executeIntentInternal(promptToRun: inputPrompt, wasCorrected: false)
        }
    }
    
    private func executeIntentInternal(promptToRun: String, wasCorrected: Bool) {
        Task {
            let intent = await broker.resolveIntent(from: promptToRun, wasCorrected: wasCorrected)
            
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

// MARK: - 9. TAB 1: Core Engine View

struct CoreEngineTab: View {
    @ObservedObject var broker: EdgeIntelligenceBroker
    @ObservedObject var healer: SelfHealingEngine
    @Binding var selectedDemographic: UserDemographic
    @Binding var selectedPosture: DevicePosture
    @Binding var simulatedLux: Double
    @Binding var isDarkMode: Bool
    @Binding var forceNeuralAura: Bool
    let layout: LayoutConfig
    let palette: AdaptivePalette
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                onDeviceAIHUDCard
                selfHealingBannerCard
                environmentControlsCard
            }
            .padding()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Core Engine Telemetry")
                    .font(.system(size: 20 + layout.fontOffset, weight: .bold))
                    .foregroundColor(palette.textPrimary)
                Text("Hardware Telemetry & Self-Healing Diagnostics")
                    .font(.system(size: 12 + layout.fontOffset))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            Circle()
                .fill(healer.isGlitchActive ? Color.red : Color.green)
                .frame(width: 10, height: 10)
        }
    }
    
    private var onDeviceAIHUDCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("On-Device AI Telemetry HUD", systemImage: "cpu.fill")
                    .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                    .foregroundColor(palette.textPrimary)
                Spacer()
                Text("100% Offline / AirPlane Safe")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            HStack(spacing: 12) {
                telemetryMetric(title: "NPU Load", value: "\(broker.npuLoad)%", color: .purple)
                telemetryMetric(title: "Tokens/sec", value: "\(String(format: "%.1f", broker.tokensPerSec))", color: .blue)
                telemetryMetric(title: "TTFT Latency", value: "\(broker.ttftMs) ms", color: .orange)
                telemetryMetric(title: "RAM Usage", value: "\(broker.ramUsageMB) MB", color: .green)
            }
            
            Toggle("Neural Aura Border Glow", isOn: $forceNeuralAura)
                .font(.system(size: 12 + layout.fontOffset))
                .foregroundColor(palette.textSecondary)
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(16)
    }
    
    private func telemetryMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(palette.textSecondary)
            Text(value)
                .font(.system(size: 12 + layout.fontOffset, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(palette.bg)
        .cornerRadius(8)
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
    }
    
    private var environmentControlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ambient Signals & Device Posture", systemImage: "slider.horizontal.3")
                .font(.system(size: 14 + layout.fontOffset, weight: .semibold))
                .foregroundColor(palette.textPrimary)
            
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
}

// MARK: - 10. TAB 2: Chat View

struct ChatTab: View {
    @ObservedObject var broker: EdgeIntelligenceBroker
    @Binding var inputPrompt: String
    @Binding var isListeningVoice: Bool
    @Binding var showCotTrace: Bool
    var isInputFocused: FocusState<Bool>.Binding
    let layout: LayoutConfig
    let palette: AdaptivePalette
    let onSendTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding()
            
            ScrollView {
                VStack(spacing: 16) {
                    messageStreamView
                    privacyRadarCard
                    chainOfThoughtCard
                }
                .padding(.horizontal)
            }
            
            inputSectionView
                .padding()
                .background(palette.surface)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("On-Device AI Chat")
                    .font(.system(size: 20 + layout.fontOffset, weight: .bold))
                    .foregroundColor(palette.textPrimary)
                Text("Typing Neural Aura & Typo Correction Assist")
                    .font(.system(size: 12 + layout.fontOffset))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(broker.isProcessing ? Color.purple : Color.green)
                    .frame(width: 8, height: 8)
                Text(broker.isProcessing ? "Inferring" : "100% Offline")
                    .font(.caption2.bold())
                    .foregroundColor(palette.textSecondary)
            }
        }
    }
    
    private var messageStreamView: some View {
        VStack(spacing: 12) {
            ForEach(broker.messages) { msg in
                HStack {
                    if msg.sender == .user { Spacer() }
                    
                    VStack(alignment: msg.sender == .user ? .trailing : .leading, spacing: 4) {
                        if msg.isCorrected {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 10))
                                Text("AI Typo Corrected")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.purple)
                        }
                        
                        Text(msg.text)
                            .font(.system(size: 13 + layout.fontOffset))
                            .foregroundColor(msg.sender == .user ? .white : palette.textPrimary)
                            .padding(12)
                            .background(msg.sender == .user ? palette.accent : palette.surface)
                            .cornerRadius(16)
                    }
                    
                    if msg.sender == .ai { Spacer() }
                }
            }
        }
    }
    
    private var inputSectionView: some View {
        VStack(spacing: 10) {
            if isInputFocused.wrappedValue && !inputPrompt.isEmpty {
                HStack {
                    Image(systemName: "wand.and.rays")
                        .foregroundColor(.purple)
                    Text("AI Real-Time Typing Assist Active (Analyzing input...)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple)
                    Spacer()
                }
                .padding(6)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(8)
            }
            
            if isListeningVoice {
                HStack {
                    Text("Voice Listener Active:")
                        .font(.caption)
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    VoiceWaveformView(accentColor: palette.accent)
                }
                .padding(8)
                .background(palette.bg)
                .cornerRadius(10)
            }
            
            // Senior Typo Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton("Senior Typo Prompt", prompt: "Snd 2500 dolars to alic card 4111-2222-3333-4444 ssn 123-45-6789")
                    presetButton("Pay $50 Dinner", prompt: "Py 50 doller to Bob for dinenr")
                    presetButton("General Inquiry", prompt: "Wat is my current balance please")
                }
            }
            
            HStack(spacing: 8) {
                Button(action: { isListeningVoice.toggle() }) {
                    Image(systemName: isListeningVoice ? "mic.fill" : "mic.slash")
                        .foregroundColor(isListeningVoice ? .red : palette.accent)
                        .padding(12)
                        .background(palette.bg)
                        .clipShape(Circle())
                }
                
                TextField("Type prompt or message...", text: $inputPrompt)
                    .focused(isInputFocused)
                    .font(.system(size: 14 + layout.fontOffset))
                    .padding(12)
                    .background(palette.bg)
                    .cornerRadius(12)
                    .foregroundColor(palette.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((isInputFocused.wrappedValue && !inputPrompt.isEmpty) ? Color.purple.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
                
                Button(action: onSendTap) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(palette.accent)
                        .clipShape(Circle())
                }
            }
        }
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
    
    private var privacyRadarCard: some View {
        Group {
            if !broker.lastSanitizedInput.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("PRIVACY RADAR AUDIT")
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
                .padding()
                .background(palette.surface)
                .cornerRadius(14)
            }
        }
    }
    
    private var chainOfThoughtCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { showCotTrace.toggle() }) {
                HStack {
                    Label("On-Device Chain-of-Thought (CoT)", systemImage: "brain.head.profile")
                        .font(.system(size: 13 + layout.fontOffset, weight: .semibold))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                    Image(systemName: showCotTrace ? "chevron.up" : "chevron.down")
                        .foregroundColor(palette.textSecondary)
                }
            }
            
            if showCotTrace {
                if broker.cotSteps.isEmpty {
                    Text("No active model inference trace.")
                        .font(.caption)
                        .foregroundColor(palette.textSecondary)
                        .padding(6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(broker.cotSteps) { step in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: step.icon)
                                    .font(.caption2)
                                    .foregroundColor(palette.accent)
                                    .frame(width: 14)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(step.phase)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(palette.textPrimary)
                                        Spacer()
                                        Text(step.timestamp)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(palette.textSecondary)
                                    }
                                    Text(step.detail)
                                        .font(.system(size: 9))
                                        .foregroundColor(palette.textSecondary)
                                }
                            }
                            .padding(6)
                            .background(palette.bg)
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(palette.surface)
        .cornerRadius(14)
    }
}

// MARK: - 11. AI Smart Correction Modal View

struct SmartCorrectionModalView: View {
    let suggestion: CorrectionSuggestion
    let palette: AdaptivePalette
    let onAccept: () -> Void
    let onRejectOriginal: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("AI Smart Correction Assist")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("Senior Assist Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.3))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
                
                Text("On-Device AI detected typos in your text and suggests a clearer version:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ORIGINAL TYPED TEXT:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                        Text(suggestion.originalText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI SUGGESTED CORRECTION:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text(suggestion.correctedText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                    }
                    
                    Text(suggestion.explanation)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
                
                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept AI Correction & Process")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onRejectOriginal) {
                        Text("Use My Original Message")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(20)
            .background(Color(white: 0.14))
            .cornerRadius(22)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 12. Enhanced Cognitive "Pause" Interceptor Modal

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
