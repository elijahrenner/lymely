import SwiftUI
import CoreML
import Vision
import UIKit
import MapKit
import MapboxMaps
import MapboxCoreMaps
import MapboxCommon
import AVFoundation

/// The main view of the Lymely app, providing access to various features including rash classification,
/// survey taking, history viewing, and additional resources about Lyme disease.
struct ContentView: View {
    // MARK: - Properties
    
    /// The image selected or taken by the user for classification.
    @State private var image: UIImage?
    
    /// The result of the rash classification.
    @State private var classificationLabel = "Take or choose a photo"
    
    /// A flag to show/hide the image picker.
    @State private var showingImagePicker = false
    
    /// A flag to determine if the camera should be used for image capture.
    @State private var isCamera = false
    
    /// A flag to show/hide the survey view.
    @State private var showingSurvey = false
    
    /// A flag to show/hide the survey history view.
    @State private var showingHistory = false
    
    /// A flag to show/hide the disclaimer alert.
    @State private var showingDisclaimer = false
    
    /// An object to manage camera permissions.
    @StateObject private var cameraPermission = CameraPermission()

    /// A shared instance of SurveyDataManager to manage survey data.
    @ObservedObject var dataManager = SurveyDataManager.shared

    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App Title and Subtitle
                VStack {
                    Text("Lymely")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Text("Your guide to staying ahead of Lyme disease.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Rash Classifier Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("🔍 Rash Classifier")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingDisclaimer = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                        .alert(isPresented: $showingDisclaimer) {
                            Alert(
                                title: Text("Disclaimer"),
                                message: Text("The rash classifier is designed specifically for identifying rashes. It may yield inaccurate results if used to evaluate bare skin, non-skin surfaces, or other objects. Furthermore, the model achieves around 80% accuracy on out-of-training data. Please use it with caution."),
                                dismissButton: .default(Text("Got it!"))
                            )
                        }
                    }
                    
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(10)
                    }
                    
                    Text(classificationLabel)
                        .font(.subheadline)
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            Task {
                                await cameraPermission.getCameraPermission()
                                if cameraPermission.isCameraPermissionGranted {
                                    isCamera = true
                                    showingImagePicker = true
                                }
                            }
                        }) {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            isCamera = false
                            showingImagePicker = true
                        }) {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Divider()
                    .padding(.horizontal)
                
                // Check Up Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("🧑‍⚕️ Check Up")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        
                        Button(action: {
                            showingSurvey.toggle()
                        }) {
                            Label("Take Survey", systemImage: "square.and.pencil")
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showingHistory.toggle()
                        }) {
                            Label("View History", systemImage: "clock.arrow.circlepath")
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    
                    if let latestReport = dataManager.latestReport {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Risk Score: \(latestReport.riskScore)")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(riskColor(for: latestReport.riskScore))
                            Text("🚨 Doctor Urgency: \(latestReport.doctorUrgency) | ⏳ Estimated Stage: \(latestReport.estimatedStage)")
                                .font(.headline)
                            
                            Text(latestReport.report)
                                .font(.body)
                                .padding(.top, 5)
                            
                            DisclosureGroup("Citations:") {
                                VStack(alignment: .leading) {
                                    let citations = latestReport.evidence.split(separator: "\n").map { String($0) }
                                    ForEach(citations.indices, id: \.self) { index in
                                        Text("\(citations[index])")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)
                
                // Lyme Disease Map Section
                VStack(alignment: .leading, spacing: 5) {
                    Text("🗺️ Lyme Disease Map")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("In cases per 100,000 people")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    FullscreenMapView()
                        .cornerRadius(10)
                        .padding(.top, 5)
                    
                    Text("Data source: [CDC Lyme Disease Surveillance and Data](https://www.cdc.gov/lyme/data-research/facts-stats/) (2022)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Additional Resources Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("📚 Additional Resources")
                        .font(.headline)
                    
                    ResourceButton(label: "🔍 Learn More About Lyme Disease", color: Color.blue.opacity(0.8), icon: "info.circle", url: "https://www.cdc.gov/lyme/communication-resources/index.html")
                    ResourceButton(label: "🛡️ Prevention Tips", color: Color.blue.opacity(0.6), icon: "shield.fill", url: "https://lyme.health.harvard.edu/lyme-disease-prevention-and-action/")
                    ResourceButton(label: "🪳 Identifying Ticks", color: Color.blue.opacity(0.4), icon: "ant.fill", url: "https://www.mayoclinic.org/diseases-conditions/alpha-gal-syndrome/in-depth/tick-species/art-20546861")
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $image, classificationLabel: $classificationLabel, isCamera: $isCamera)
        }
        .sheet(isPresented: $showingSurvey) {
            SurveyView()
        }
        .sheet(isPresented: $showingHistory) {
            SurveyHistoryView()
        }
    }
    
    /// Determines the color to use for displaying the risk score.
    /// - Parameter score: The risk score to evaluate.
    /// - Returns: A Color corresponding to the risk level (green for low, yellow for medium, red for high).
    func riskColor(for score: Int) -> Color {
        switch score {
        case 0..<30:
            return .green
        case 30..<70:
            return .yellow
        default:
            return .red
        }
    }
}

/// A custom button view for displaying resource links.
struct ResourceButton: View {
    /// The text to display on the button.
    var label: String
    
    /// The background color of the button.
    var color: Color
    
    /// The name of the SF Symbol to use as an icon.
    var icon: String
    
    /// The URL to open when the button is tapped.
    var url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: icon)
            }
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

/// A preview provider for the ContentView.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
