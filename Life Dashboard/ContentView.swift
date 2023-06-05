import SwiftUI
import HealthKit

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            HealthKitManager.shared.requestHealthKitAuthorization()
            HealthKitManager.shared.fetchLatestHealthData { success in
                print("Fetched health data with success: \(success)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
