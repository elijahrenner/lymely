import Foundation
import SwiftUI

// MARK: - Data Models

/// Represents the data collected from a single survey submission
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

/// Represents a risk assessment report generated based on survey data
struct Report: Identifiable, Codable {
    let id: UUID
    let date: Date
    let riskScore: Int
    let report: String
    let evidence: String
}

// MARK: - SurveyDataManager

/// Manages the storage and retrieval of survey data and reports
class SurveyDataManager: ObservableObject {
    /// Shared instance of the SurveyDataManager
    static let shared = SurveyDataManager()
    
    /// Published property containing an array of survey results
    @Published var surveyResults: [SurveyData] = []
    
    /// Published property containing the latest generated report
    @Published var latestReport: Report? = nil

    /// Private initializer to enforce singleton pattern
    private init() {
        loadSurveyResults()
        loadLatestReport()
    }

    /// Adds a new survey result to the collection and saves it
    /// - Parameter surveyData: The new survey data to be added
    func addSurveyResult(_ surveyData: SurveyData) {
        surveyResults.append(surveyData)
        saveSurveyResults()
    }

    /// Saves the current survey results to a file
    func saveSurveyResults() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        do {
            let data = try encoder.encode(surveyResults)
            let url = getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            try data.write(to: url)
        } catch {
            print("Failed to save survey results: \(error)")
        }
    }

    /// Loads survey results from a file
    func loadSurveyResults() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        do {
            let url = getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            let data = try Data(contentsOf: url)
            surveyResults = try decoder.decode([SurveyData].self, from: data)
        } catch {
            print("Failed to load survey results: \(error)")
        }
    }

    /// Returns the app's documents directory
    /// - Returns: URL of the app's documents directory
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// Sets and saves the latest report
    /// - Parameter report: The new report to be set as the latest
    func setLatestReport(_ report: Report) {
        latestReport = report
        saveLatestReport()
    }
    
    /// Saves the latest report to a file
    private func saveLatestReport() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        do {
            let data = try encoder.encode(latestReport)
            let url = getDocumentsDirectory().appendingPathComponent("latestReport.json")
            try data.write(to: url)
        } catch {
            print("Failed to save latest report: \(error)")
        }
    }

    /// Loads the latest report from a file
    private func loadLatestReport() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        do {
            let url = getDocumentsDirectory().appendingPathComponent("latestReport.json")
            let data = try Data(contentsOf: url)
            latestReport = try decoder.decode(Report.self, from: data)
        } catch {
            print("Failed to load latest report: \(error)")
        }
    }
    
    /// Clears all survey results
    func clearSurveyResults() {
        surveyResults.removeAll()
        saveSurveyResults()
    }
}

/// View for collecting daily survey data
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
    
    var body: some View {
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
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
        }
    }
    
    /// View for symptom selection
    private var symptomSelection: some View {
        VStack(alignment: .leading) {
            ForEach(symptoms, id: \.self) { symptom in
                HStack {
                    Image(systemName: selectedSymptoms.contains(symptom) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedSymptoms.contains(symptom) ? .blue : .gray)
                    Text(symptom)
                        .onTapGesture {
                            toggleSymptom(symptom)
                        }
                }
                .padding(.vertical, 5)
            }
        }
        .padding(.horizontal)
    }
    
    /// View for additional information input
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
    
    /// View for the submit button
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
    
    /// Toggles the selection state of a symptom
    /// - Parameter symptom: The symptom to toggle
    private func toggleSymptom(_ symptom: String) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.removeAll { $0 == symptom }
        } else {
            selectedSymptoms.append(symptom)
        }
    }
    
    /// Submits the survey data and generates a risk assessment report
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
        
        guard let historyData = loadFullPatientHistory() else {
            print("Failed to load full patient history.")
            return
        }
        
        let patientHistory = """
        Instructions: 
        {
          "prompt": "You are a health risk assessment assistant specializing in tickborne illnesses. Your task is to analyze a user's survey history data, calculate a risk score, and generate a detailed report explaining the risk assessment, including evidence by quoting relevant information.

        You must NEVER definitively diagnose a patient. Instead, assess risk based on this guide. Always encourage them to seek medical attention if their risk is high.
        
        From the CDC, here are some early symptoms:
        
        Early signs and symptoms (3 to 30 days after tick bite)
        Fever, chills, headache, fatigue, muscle and joint aches, and swollen lymph nodes may occur in the absence of rash
        Erythema migrans (EM) rash:
        Occurs in approximately 70 to 80 percent of infected people
        Begins at the site of a tick bite after a delay of 3 to 30 days (average is about 7 days)
        Expands gradually over several days reaching up to 12 inches (30 cm) or more across
        May feel warm to the touch but is rarely itchy or painful
        Sometimes clears as it enlarges, resulting in a target or "bull's-eye" appearance
        May appear on any area of the body
        Does not always appear as a "classic bull's-eye" rash

        Your Tasks:
        1. Analyze the Survey History Data:
           - Review the user's survey responses over time.
           - Identify activities that increase tick exposure risk (e.g., spending time outdoors in tick-prone areas).
           - Note any preventive measures taken (e.g., using bug spray, performing tick checks).
           - Recognize any reported symptoms associated with tickborne illnesses.
           - Consider information from the guide to support your analysis.

        2. Calculate the Risk Score:
           - Based on the survey data and the information from the guide, calculate a risk score between 0 and 100, where higher scores indicate greater risk.
           - Factor in exposure levels, preventive actions, symptoms, and additional information.
           - Use evidence by quoting directly from the guide (e.g., \"The risk of tick exposure increases significantly in wooded areas, especially without protective measures.\" [1]).

        3. Generate the Report with Evidence:
           - Write a clear, concise report explaining the factors contributing to the risk score.
           - Include in-text citations in the report using the format [n], where 'n' is the corresponding number of the citation.
           - Provide a separate evidence section where each citation is listed as \"[n] Citation text\", with 'n' corresponding to the in-text citation used in the report.
           - Provide recommendations for the user, such as seeking medical advice or taking preventive measures.
           - Ensure the report is easily understandable and user-friendly.

        Input Format:
        You will receive the survey history data in JSON format as shown below:

        {
          "survey_history": [
            {
              "date": "YYYY-MM-DD",
              "spentTimeOutdoors": true/false,
              "usedBugSpray": true/false,
              "checkedForTicks": true/false,
              "foundTicks": true/false,
              "selectedSymptoms": ["Symptom1", "Symptom2", ...],
              "additionalInfo": "string" // Optional additional information provided by the user
            }
          ]
        }

        Output Format:
        Provide your response in the following JSON format:

        {
          "risk_score": number,
          "report": "string",
          "evidence": ["string", "string", ...]
        }

        Explanation of Fields:
        - risk_score: An integer between 0 and 100.
        - report: A detailed explanation of the risk assessment, containing in-text citations in the format [n].
        - evidence: An array of strings, each formatted as \"[n] Citation text\", where 'n' corresponds to the citation used in the report.

        Example Response (JSON):

        {
          "risk_score": 80,
          "report": "Based on your recent activities, you have a high risk of tick exposure. You spent multiple days outdoors in wooded areas without consistently using bug spray, and you reported symptoms such as fatigue and muscle pain, which are common early signs of tickborne illnesses [1]. We recommend performing thorough tick checks and consulting a healthcare professional.",
          "evidence": [
            "[1] On Month Date, you reported symptoms of fatigue and muscle pain."
          ]
        }

        Guidelines:
        - Be Analytical: Use the survey data and guide information to make an informed assessment.
        - Cite Evidence: Include relevant symptoms/activities at certain times from the history to support your conclusions, and provide structured citations with corresponding IDs. Do NOT include facts about Lyme in your citations. Only cite the time some activity/event happened.
        - Ensure the evidence array contains citation entries in the format \"[n] Citation text\", with 'n' matching the in-text citations in the report.
        - Be Empathetic: Communicate in a supportive and encouraging manner.
        - Be Clear and Concise: Ensure your report and evidence are easy to understand.
        - Quote ONLY from the guide you are provided with. Do not use any other sources or links.
        - Output ONLY in JSON format. Do not add ANY plaintext outside of the JSON structure. Failure to comply will result in errors.
        - Ensure the JSON is properly formatted with no syntax errors.
        - The response should start with '{' and end with '}' without any preceding or trailing characters.**

          Output Format:
          Provide your response in the following JSON format:

          {
            "risk_score": number,
            "report": "string",
            "evidence": ["string", "string", ...]
          }

          Ensure that ONLY the JSON structure above is returned. Do not add any text before or after the JSON."
        }

        Full Patient History:
        \(historyData)

        Latest Survey Data:
        - Spent time outdoors: \(spentTimeOutdoors ? "Yes" : "No")
        - Used bug spray: \(usedBugSpray ? "Yes" : "No")
        - Checked for ticks: \(checkedForTicks ? "Yes" : "No")
        - Found ticks: \(foundTicks ? "Yes" : "No")
        - Symptoms: \(selectedSymptoms.isEmpty ? "None" : selectedSymptoms.joined(separator: ", "))
        - Additional Information: \(additionalInfo.isEmpty ? "None" : additionalInfo)
        """

        
        callOpenAIAPI(prompt: patientHistory) { response in
            if let response = response {
                print("Assistant response: \(response)")
                if let report = parseOpenAIResponse(response) {
                    dataManager.setLatestReport(report)
                } else {
                    print("Failed to parse OpenAI response.")
                }
            } else {
                print("Failed to get a response from the assistant.")
            }
        }
        
        dismiss()
    }
    
    /// Loads the full patient history from stored survey results
    /// - Returns: A string representation of the patient's survey history
    func loadFullPatientHistory() -> String? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        do {
            let url = SurveyDataManager.shared.getDocumentsDirectory().appendingPathComponent("surveyResults.json")
            let data = try Data(contentsOf: url)
            let history = try decoder.decode([SurveyData].self, from: data)
            
            let historyString = history.map { data in
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
            
            return historyString
        } catch {
            print("Error loading patient history: \(error)")
            return nil
        }
    }
    
    /// Date formatter for consistent date formatting
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Calls the OpenAI API to generate a risk assessment report
    /// - Parameters:
    ///   - prompt: The prompt to send to the OpenAI API
    ///   - completion: A closure to handle the API response
    func callOpenAIAPI(prompt: String, completion: @escaping (String?) -> Void) {
        // Access the API key from the info.plist
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String else {
            print("API Key not found.")
            completion(nil)
            return
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": "gpt-4o", // Corrected model name
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.75
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("Error serializing request body: \(error)")
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error making request: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                completion(nil)
                return
            }

            // Print the status code for debugging
            print("HTTP Status Code: \(httpResponse.statusCode)")

            guard let data = data else {
                print("No data returned")
                completion(nil)
                return
            }

            // For debugging, print the response data as a string
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Data: \(responseString)")
            }

            do {
                if httpResponse.statusCode == 200 {
                    // Parse the successful response
                    if let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let choices = responseJSON["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let assistantResponse = message["content"] as? String {
                        completion(assistantResponse)
                    } else {
                        print("Error parsing response")
                        completion(nil)
                    }
                } else {
                    // Parse the error response
                    if let errorJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let errorMessage = errorJSON["error"] as? [String: Any],
                       let message = errorMessage["message"] as? String {
                        print("API Error: \(message)")
                        completion(nil)
                    } else {
                        print("Unknown error occurred")
                        completion(nil)
                    }
                }
            } catch {
                print("Error decoding JSON response: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    /// Parses the OpenAI API response and creates a Report object
    /// - Parameter response: The response string from the OpenAI API
    /// - Returns: A Report object if parsing is successful, nil otherwise
    func parseOpenAIResponse(_ response: String) -> Report? {
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        func stripCodeFences(from text: String) -> String {
            var text = text
            
            let codeFences = ["```json", "```", "'''json", "'''"]
            
            for fence in codeFences {
                if text.hasPrefix(fence) {
                    text = String(text.dropFirst(fence.count))
                    if text.hasPrefix("\n") {
                        text = String(text.dropFirst(1))
                    }
                }
                if text.hasSuffix(fence) {
                    text = String(text.dropLast(fence.count))
                    if text.hasSuffix("\n") {
                        text = String(text.dropLast(1))
                    }
                }
            }
            
            return text
        }
        
        cleanedResponse = stripCodeFences(from: cleanedResponse)
        
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        print("Cleaned Response: \(cleanedResponse)")
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("Failed to convert response to Data.")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
            
            let evidenceText = openAIResponse.evidence.joined(separator: "\n")
            
            let report = Report(
                id: UUID(),
                date: Date(),
                riskScore: openAIResponse.risk_score,
                report: openAIResponse.report,
                evidence: evidenceText
            )
            
            return report
        } catch {
            print("Error decoding OpenAIResponse: \(error)")
            return nil
        }
    }

    
    /// Represents the structure of the OpenAI API response
    struct OpenAIResponse: Codable {
        let risk_score: Int
        let report: String
        let evidence: [String]
    }
}

struct SurveyView_Previews: PreviewProvider {
    static var previews: some View {
        SurveyView()
    }
}

/// View for displaying a single survey result
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
                        Text("None")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(surveyData.selectedSymptoms, id: \.self) { symptom in
                            Text("- \(symptom)")
                        }
                    }
                    
                    if let additionalInfo = surveyData.additionalInfo, !additionalInfo.isEmpty {
                        Text("💬 Additional Information:")
                            .font(.headline)
                        Text(additionalInfo)
                    }
                }
                .font(.body)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("🔍 Survey Result")
        .navigationBarItems(trailing: Button("Close") {
            dismiss()
        })
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

/// View for displaying the history of survey results
struct SurveyHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager = SurveyDataManager.shared
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            VStack {
                if dataManager.surveyResults.isEmpty {
                    Spacer()
                    Text("No survey history available.")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(dataManager.surveyResults.sorted(by: { $0.date > $1.date })) { survey in
                            NavigationLink(destination: SurveyResultView(surveyData: survey)) {
                                VStack(alignment: .leading) {
                                    Text(dateFormatter.string(from: survey.date))
                                        .font(.headline)
                                    HStack {
                                        Label(survey.spentTimeOutdoors ? "Spent Outdoors" : "Stayed Indoors", systemImage: survey.spentTimeOutdoors ? "leaf.fill" : "house.fill")
                                        Spacer()
                                        Label(survey.foundTicks ? "Found Ticks" : "No Ticks Found", systemImage: survey.foundTicks ? "ant.fill" : "ant")
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
                leading: Button("Close") {
                    dismiss()
                },
                trailing: Button(action: {
                    showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(dataManager.surveyResults.isEmpty)
            )
            .alert(isPresented: $showClearConfirmation) {
                Alert(
                    title: Text("Clear History"),
                    message: Text("Are you sure you want to delete all survey history? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        dataManager.clearSurveyResults()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    /// Deletes individual surveys from the history
    /// - Parameter offsets: The indices of the surveys to be deleted
    private func deleteSurvey(at offsets: IndexSet) {
        dataManager.surveyResults.remove(atOffsets: offsets)
        dataManager.saveSurveyResults()
    }

    /// Date formatter for consistent date formatting
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
