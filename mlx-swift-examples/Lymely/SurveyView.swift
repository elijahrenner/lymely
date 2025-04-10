import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Tokenizers
import SwiftfulLoadingIndicators

// MARK: - Data Models

struct SurveyData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let spentTimeOutdoors: Bool
    let usedBugSpray: Bool
    let checkedForTicks: Bool
    let foundTicks: Bool
    let selectedSymptoms: [String]
    let additionalInfo: String?
}

struct Report: Identifiable, Codable {
    let id: UUID
    let date: Date
    let riskScore: Int
    let doctorUrgency: String
    let estimatedStage: String
    let report: String
    let evidence: String
}

// MARK: - SurveyDataManager

class SurveyDataManager: ObservableObject {
    static let shared = SurveyDataManager()
    
    @Published var surveyResults: [SurveyData] = []
    @Published var latestReport: Report? = nil
    
    private init() {
        loadSurveyResults()
        loadLatestReport()
    }
    
    func addSurveyResult(_ surveyData: SurveyData) {
        surveyResults.append(surveyData)
        saveSurveyResults()
    }
    
    func saveSurveyResults() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        do {
            let data = try encoder.encode(surveyResults)
            let url = getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            try data.write(to: url)
            print("SurveyDataManager: Survey results saved to \(url.path)")
        } catch {
            print("SurveyDataManager: Failed to save survey results: \(error)")
        }
    }
    
    func loadSurveyResults() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            let url = getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            let data = try Data(contentsOf: url)
            surveyResults = try decoder.decode([SurveyData].self, from: data)
            print("SurveyDataManager: Loaded survey results from \(url.path)")
        } catch {
            print("SurveyDataManager: Failed to load survey results: \(error)")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func setLatestReport(_ report: Report) {
        latestReport = report
        saveLatestReport()
    }
    
    private func saveLatestReport() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        do {
            let data = try encoder.encode(latestReport)
            let url = getDocumentsDirectory().appendingPathComponent("latestReport.json")
            try data.write(to: url)
            print("SurveyDataManager: Latest report saved to \(url.path)")
        } catch {
            print("SurveyDataManager: Failed to save latest report: \(error)")
        }
    }
    
    private func loadLatestReport() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            let url = getDocumentsDirectory().appendingPathComponent("latestReport.json")
            let data = try Data(contentsOf: url)
            latestReport = try decoder.decode(Report.self, from: data)
            print("SurveyDataManager: Loaded latest report from \(url.path)")
        } catch {
            print("SurveyDataManager: Failed to load latest report: \(error)")
        }
    }
    
    func clearSurveyResults() {
        surveyResults.removeAll()
        saveSurveyResults()
    }
}

// MARK: - SurveyView

struct SurveyView: View {
    @State private var spentTimeOutdoors = false
    @State private var usedBugSpray = false
    @State private var checkedForTicks = false
    @State private var foundTicks = false
    @State private var selectedSymptoms: [String] = []
    let symptoms = ["Fatigue", "Fever or chills", "Headache", "Muscle or joint pain", "Rash", "None of the above"]
    @State private var additionalInfo: String = ""
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager = SurveyDataManager.shared
    @StateObject private var evaluator = SurveyLLMEvaluator() // Updated evaluator with progress tracking
    
    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Toggle("🌳 Did you spend time outdoors in grassy or wooded areas today?", isOn: $spentTimeOutdoors)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        Toggle("🦟 Did you use bug spray or tick repellent today?", isOn: $usedBugSpray)
                            .padding(.horizontal)
                        
                        Toggle("🔍 Did you check for ticks on yourself or others today?", isOn: $checkedForTicks)
                            .padding(.horizontal)
                        
                        Toggle("🪲 Did you find any ticks on yourself, others, or your pets today?", isOn: $foundTicks)
                            .padding(.horizontal)
                        
                        Text("🤒 Do you have any of the following symptoms today? (Select all that apply)")
                            .bold()
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        symptomSelection
                        additionalInfoSection
                        submitButton
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 20)
                }
                .navigationTitle("📝 Daily Survey")
                .navigationBarItems(trailing: Button("Close") { dismiss() })
            }
            .onAppear {
                Task {
                    do {
                        let _ = try await evaluator.load()
                    } catch {
                        print("SurveyView: Failed to preload model: \(error)")
                    }
                }
            }
            // NEW: Show a progress overlay when downloading or generating
            if evaluator.downloadProgress < 1.0 || evaluator.isGenerating {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 16) {
                        if evaluator.downloadProgress < 1.0 {
                            Text("Downloading model: \(Int(evaluator.downloadProgress * 100))%")
                                .font(.title2).bold()
                            ProgressView(value: evaluator.downloadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.horizontal, 40)
                        } else {
                            Text("Please be patient while Lymely works on your report...")
                                .font(.title2).bold()
                            LoadingIndicator(animation: .threeBallsBouncing, size: .medium)
                        }
                    }
                }
            }
        }
    }
    private var symptomSelection: some View {
        VStack(alignment: .leading) {
            ForEach(symptoms, id: \.self) { symptom in
                HStack {
                    Image(systemName: selectedSymptoms.contains(symptom) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedSymptoms.contains(symptom) ? .blue : .gray)
                    Text(symptom)
                        .onTapGesture { toggleSymptom(symptom) }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal)
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading) {
            Text("💬 Additional Information (optional)")
                .bold()
                .padding(.horizontal)
                .padding(.top, 10)
            TextEditor(text: $additionalInfo)
                .frame(height: 100)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
                .padding(.horizontal)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitSurvey) {
            Text("Submit Survey")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func toggleSymptom(_ symptom: String) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.removeAll { $0 == symptom }
        } else {
            selectedSymptoms.append(symptom)
        }
    }
    
    private func submitSurvey() {
        let newSurveyData = SurveyData(
            id: UUID(),
            date: Date(),
            spentTimeOutdoors: spentTimeOutdoors,
            usedBugSpray: usedBugSpray,
            checkedForTicks: checkedForTicks,
            foundTicks: foundTicks,
            selectedSymptoms: selectedSymptoms,
            additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo
        )
        dataManager.addSurveyResult(newSurveyData)
        print("SurveyView: New survey submitted at \(Date()).")
        
        guard let historyData = loadFullPatientHistory() else {
            print("SurveyView: Failed to load full patient history.")
            return
        }
        
        let patientHistory = """
        Most Recent Patient History:
        \(historyData)

        Latest Survey Data:
        - Spent time outdoors: \(spentTimeOutdoors ? "Yes" : "No")
        - Used bug spray: \(usedBugSpray ? "Yes" : "No")
        - Checked for ticks: \(checkedForTicks ? "Yes" : "No")
        - Found ticks: \(foundTicks ? "Yes" : "No")
        - Symptoms: \(selectedSymptoms.isEmpty ? "None" : selectedSymptoms.joined(separator: ", "))
        - Additional Information: \(additionalInfo.isEmpty ? "None" : additionalInfo)
        """
        
        Task {
            print("SurveyView: Starting report generation...")
            await evaluator.generateReport(prompt: patientHistory)
            let response = evaluator.output
            if let report = evaluator.parseResponse(response) {
                dataManager.setLatestReport(report)
                print("SurveyView: Report generation and parsing succeeded.")
            } else {
                print("SurveyView: Failed to parse local inference response.")
            }
            dismiss()
        }
    }
    
    func loadFullPatientHistory() -> String? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            let url = SurveyDataManager.shared.getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            let data = try Data(contentsOf: url)
            let history = try decoder.decode([SurveyData].self, from: data)
            print("SurveyView: Loaded full patient history from \(url.path)")
            return history.map { data in
                let formattedDate = dateFormatter.string(from: data.date)
                return """
                Date: \(formattedDate)
                - Spent time outdoors: \(data.spentTimeOutdoors ? "Yes" : "No")
                - Used bug spray: \(data.usedBugSpray ? "Yes" : "No")
                - Checked for ticks: \(data.checkedForTicks ? "Yes" : "No")
                - Found ticks: \(data.foundTicks ? "Yes" : "No")
                - Symptoms: \(data.selectedSymptoms.isEmpty ? "None" : data.selectedSymptoms.joined(separator: ", "))
                - Additional Information: \(data.additionalInfo ?? "None")
                """
            }.joined(separator: "\n\n")
        } catch {
            print("SurveyView: Error loading patient history: \(error)")
            return nil
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
// MARK: - Local Inference Evaluator

@MainActor
class SurveyLLMEvaluator: ObservableObject {
    @Published var tokenCount: Int = 0
    @Published var isGenerating: Bool = false
    @Published var tokenHistogram: [Double] = []
    // NEW: Published download progress (0.0 to 1.0)
    @Published var downloadProgress: Double = 0.0
    var output = ""
    var modelInfo = ""
    var stat = ""
    
    let modelConfiguration = ModelRegistry.llama3_1_8B_4bit
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 1000000
    let displayEveryNTokens = 4
    
    enum LoadState {
        case idle, loaded(ModelContainer)
    }
    
    var loadState: LoadState = .idle
    var container: ModelContainer?  // <-- NEW
    
    func load() async throws -> ModelContainer {
        if case .loaded(let loadedContainer) = loadState {
            self.container = loadedContainer
            return loadedContainer
        }
        print("SurveyLLMEvaluator: Starting model load for \(self.modelConfiguration.name)")
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        let newContainer = try await LLMModelFactory.shared.loadContainer(configuration: self.modelConfiguration) { progress in
            Task { @MainActor in
                let percent = Int(progress.fractionCompleted * 100)
                self.downloadProgress = progress.fractionCompleted
                self.modelInfo = "Downloading \(self.modelConfiguration.name): \(percent)%"
                print("SurveyLLMEvaluator: Download progress for \(self.modelConfiguration.name): \(percent)%")
            }
        }
        let numParams = await newContainer.perform { context in
            context.model.numParameters()
        }
        self.modelInfo = "Loaded \(self.modelConfiguration.id). Weights: \(numParams / (1024*1024))M"
        print("SurveyLLMEvaluator: Model \(self.modelConfiguration.id) loaded with \(numParams / (1024*1024))M parameters")
        loadState = .loaded(newContainer)
        self.container = newContainer
        return newContainer
    }
    
    func generateReport(prompt: String) async {
        guard !self.isGenerating else { return }
        self.isGenerating = true
        self.tokenCount = 0
        self.output = ""
        print("SurveyLLMEvaluator: Starting report generation for prompt.")
        do {
            // Use the preloaded container if available.
            let container: ModelContainer
            if let preloaded = self.container {
                container = preloaded
            } else {
                container = try await load()
            }
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            // System prompt with full instructions verbatim.
            let systemPrompt = """
            You are a health risk assessment assistant for tickborne illnesses. Your task is to analyze a patient's survey history and generate a precise, evidence-based Lyme disease risk report.

            RULES (MANDATORY):

            1. **No Diagnosis:** Assess risk only. Never diagnose. If risk is elevated, recommend seeing a doctor.

            2. **Approved Sources Only:**
               - Patient history with EXACT DATE AND TIME
               - CDC: https://www.cdc.gov/lyme/signs-symptoms/index.html
               - Mayo Clinic: https://www.mayoclinic.org/diseases-conditions/lyme-disease/symptoms-causes/syc-20374651
               - Cite all claims inline with IN-SUMMARY citations like "[n]" for some number n after all claims; include exact evidence text in the `evidence` array as “[n] (the number n from before) evidence”

            3. **Risk Score (0–100):**
               - Integer only, justified by symptom presence, date, exposure, and prevention behavior

            4. **Estimated Stage (0–3):**
               - 0 = No Lyme signs
               - 1 = Early Localized (3–30 days): rash, fever, fatigue, etc.
               - 2 = Early Disseminated (3–10 weeks): neurological or cardiac symptoms
               - 3 = Late Disseminated (2–12+ months): arthritis, joint swelling
               - Justify using Mayo Clinic timing and symptoms

            5. **Doctor Urgency:**
               - One of: "Not urgent", "Semi-urgent", "Very urgent"
               - Based on symptoms and risk score; choose higher urgency if uncertain

            6. **Language Rules:**
               - Refer to the user as “you,” not “the patient”
               - No greetings or sign-offs
               - Keep tone professional, supportive, and fact-based — no fluff or vague phrasing

            7. **Use Dates Precisely:**
               - All symptoms or exposures must reference exact dates from the survey (e.g., “On Mar 28, 2025, you reported fatigue”)
               - Never generalize (“recently,” “some days,” etc.)

            8. **Behavior and Exposure Analysis:**
               - Always state whether the user: spent time outdoors, used bug spray, checked for ticks, found ticks, had symptoms
               - Mention what was and wasn’t done, with dates and relevance

            9. **Citation Format:**
               - Use inline [n] in report
               - Include matching evidence array: “[n] Verbatim source text”

            10. **Output Format (return ONLY this):**

            <BEGIN>
            {
              "risk_score": number,
              "doctor_urgency": "Not urgent" | "Semi-urgent" | "Very urgent",
              "estimated_stage": 0 | 1 | 2 | 3,
              "report": "string",
              "evidence": [
                "[1] source text",
                "[2] source text",
                ...
              ]
            }

            SYMPTOM GUIDE:

            **CDC Early Symptoms (https://www.cdc.gov/lyme/signs-symptoms/index.html):**
            - Early symptoms (3–30 days post-bite): Fever, chills, headache, fatigue, muscle/joint aches, swollen lymph nodes
            - Erythema migrans (EM) rash: ~70–80% cases; appears 3–30 days after bite; up to 12” wide, expanding, warm, rarely itchy/painful, may form bull’s-eye

            **Mayo Clinic Stages (https://www.mayoclinic.org/diseases-conditions/lyme-disease/symptoms-causes/syc-20374651):**
            - Tick bites may resemble mosquito bites and go unnoticed. Symptoms vary and often overlap.

            - **Stage 1 (3–30 days)** – Early Localized:
              - Rash, fever, fatigue, joint/muscle aches, swollen lymph nodes

            - **Stage 2 (3–10 weeks)** – Early Disseminated:
              - Stage 1 symptoms +
              - Multiple rashes, facial palsy, neck stiffness, nerve pain, irregular heartbeat, vision problems

            - **Stage 3 (2–12+ months)** – Late Disseminated:
              - All prior symptoms +
              - Intermittent or chronic arthritis (often knees), possibly skin changes in Europe

            - **See a Doctor:** If you’ve had tick exposure or compatible symptoms, consult a healthcare provider.

            """

            let input = try await container.perform { context in
                return try await context.processor.prepare(
                    input: .init(
                        messages: [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": prompt]
                        ]
                    )
                )
            }
            
            let result = try await container.perform { context in
                return try MLXLMCommon.generate(input: input, parameters: self.generateParameters, context: context) { tokens in
                    if tokens.count % self.displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        print("Generated text so far: \(text)")
                        Task { @MainActor in
                            self.output = text
                            self.tokenCount = tokens.count
                            // Append one random value per new token:
                            let newTokens = tokens.count - self.tokenHistogram.count
                            for _ in 0..<newTokens {
                                self.tokenHistogram.append(Double.random(in: 0...1))
                            }
                        }
                    }
                    return tokens.count >= self.maxTokens ? .stop : .more
                }
            }
            if result.output != self.output { self.output = result.output }
            self.stat = "Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
            print("SurveyLLMEvaluator: Generation complete with tokens per second: \(result.tokensPerSecond)")
        } catch {
            self.output = "Failed: \(error)"
            print("SurveyLLMEvaluator: Report generation failed with error: \(error)")
        }
        self.isGenerating = false
    }
    
    func parseResponse(_ response: String) -> Report? {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip code fences if present
        func stripCodeFences(from text: String) -> String {
            var text = text
            for fence in ["```json", "```", "'''json", "'''"] {
                if text.hasPrefix(fence) {
                    text = String(text.dropFirst(fence.count)).trimmingCharacters(in: .newlines)
                }
                if text.hasSuffix(fence) {
                    text = String(text.dropLast(fence.count)).trimmingCharacters(in: .newlines)
                }
            }
            return text
        }

        // Extract JSON object from response
        func extractJSONObject(from text: String) -> String? {
            guard let start = text.firstIndex(of: "{"),
                  let end = text.lastIndex(of: "}") else { return nil }
            let jsonSubstring = text[start...end]
            return String(jsonSubstring)
        }

        cleaned = stripCodeFences(from: cleaned)
        guard let jsonString = extractJSONObject(from: cleaned) else {
            print("SurveyLLMEvaluator: Failed to extract JSON object from response.")
            return nil
        }

        print("Cleaned model output: \(jsonString)")
        guard let data = jsonString.data(using: .utf8) else {
            print("SurveyLLMEvaluator: Failed to convert JSON string to Data.")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let resp = try decoder.decode(SurveyLLMResponse.self, from: data)
            let evidenceText = resp.evidence.joined(separator: "\n")
            print("SurveyLLMEvaluator: Successfully parsed response.")
            return Report(
                id: UUID(),
                date: Date(),
                riskScore: resp.risk_score,
                doctorUrgency: resp.doctor_urgency,
                estimatedStage: "\(resp.estimated_stage)",
                report: resp.report,
                evidence: evidenceText
            )
        } catch {
            print("SurveyLLMEvaluator: Error decoding response: \(error)")
            return nil
        }
    }
    
    struct SurveyLLMResponse: Codable {
        let risk_score: Int
        let doctor_urgency: String
        let estimated_stage: Int
        let report: String
        let evidence: [String]
    }
}

// MARK: - Survey History & Result Views

struct SurveyResultView: View {
    var surveyData: SurveyData
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("🌳 Spent time outdoors: \(surveyData.spentTimeOutdoors ? "Yes" : "No")")
                    Text("🦟 Used bug spray: \(surveyData.usedBugSpray ? "Yes" : "No")")
                    Text("🔍 Checked for ticks: \(surveyData.checkedForTicks ? "Yes" : "No")")
                    Text("🪲 Found ticks: \(surveyData.foundTicks ? "Yes" : "No")")
                    Text("🤒 Symptoms:")
                    if surveyData.selectedSymptoms.isEmpty {
                        Text("None").foregroundColor(.gray)
                    } else {
                        ForEach(surveyData.selectedSymptoms, id: \.self) { symptom in
                            Text("- \(symptom)")
                        }
                    }
                    if let info = surveyData.additionalInfo, !info.isEmpty {
                        Text("💬 Additional Information:").font(.headline)
                        Text(info)
                    }
                }
                .font(.body)
                Spacer()
            }
            .padding()
        }
        .navigationTitle("🔍 Survey Result")
        .navigationBarItems(trailing: Button("Close") { dismiss() })
    }
}

struct SurveyResultView_Previews: PreviewProvider {
    static var previews: some View {
        SurveyResultView(surveyData: SurveyData(
            id: UUID(),
            date: Date(),
            spentTimeOutdoors: true,
            usedBugSpray: false,
            checkedForTicks: true,
            foundTicks: false,
            selectedSymptoms: ["Fever", "Headache"],
            additionalInfo: "No additional information."
        ))
    }
}

struct SurveyHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager = SurveyDataManager.shared
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            VStack {
                if dataManager.surveyResults.isEmpty {
                    Spacer()
                    Text("No survey history available.").foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(dataManager.surveyResults.sorted { $0.date > $1.date }) { survey in
                            NavigationLink(destination: SurveyResultView(surveyData: survey)) {
                                VStack(alignment: .leading) {
                                    Text(dateFormatter.string(from: survey.date))
                                        .font(.headline)
                                    HStack {
                                        Label(survey.spentTimeOutdoors ? "Spent Outdoors" : "Stayed Indoors",
                                              systemImage: survey.spentTimeOutdoors ? "leaf.fill" : "house.fill")
                                        Spacer()
                                        Label(survey.foundTicks ? "Found Ticks" : "No Ticks Found",
                                              systemImage: survey.foundTicks ? "ant.fill" : "ant")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .onDelete(perform: deleteSurvey)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("📋 Survey History")
            .navigationBarItems(
                leading: Button("Close") { dismiss() },
                trailing: Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .disabled(dataManager.surveyResults.isEmpty)
            )
            .alert(isPresented: $showClearConfirmation) {
                Alert(
                    title: Text("Clear History"),
                    message: Text("Are you sure you want to delete all survey history? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) { dataManager.clearSurveyResults() },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func deleteSurvey(at offsets: IndexSet) {
        dataManager.surveyResults.remove(atOffsets: offsets)
        dataManager.saveSurveyResults()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct SurveyHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        SurveyHistoryView()
    }
}
