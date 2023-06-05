import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    
    private var latestHeartRate: Double?
    private var totalSteps: Double?

    func requestHealthKitAuthorization() {
        let readDataTypes: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readDataTypes) { (success, error) in
            if success {
                print("Permission granted.")
            } else if let error = error {
                print("An error occurred while requesting HealthKit permissions: \(error)")
            }
        }
    }

    func fetchLatestHealthData(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        
        group.enter()
        fetchLatestHeartRate { success in
            group.leave()
        }
        
        group.enter()
        fetchTotalSteps { success in
            group.leave()
        }
        
        group.notify(queue: .main) {
            guard let heartRate = self.latestHeartRate, let steps = self.totalSteps else {
                completion(false)
                return
            }
            
            self.sendHealthDataToServer(heartRate: heartRate, steps: steps, completion: completion)
        }
    }
    
    private func fetchLatestHeartRate(completion: @escaping (Bool) -> Void) {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples, let mostRecentSample = samples.first as? HKQuantitySample else {
                print("Failed to fetch heart rate")
                completion(false)
                return
            }
            
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            self.latestHeartRate = mostRecentSample.quantity.doubleValue(for: heartRateUnit)
            print("Most recent heart rate: \(self.latestHeartRate!) beats per minute")
            completion(true)
        }

        healthStore.execute(query)
    }
    
    private func fetchTotalSteps(completion: @escaping (Bool) -> Void) {
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, statistics, error) in
            guard let statistics = statistics, let sum = statistics.sumQuantity() else {
                print("Failed to fetch steps")
                completion(false)
                return
            }
            
            self.totalSteps = sum.doubleValue(for: HKUnit.count())
            print("Total steps today: \(self.totalSteps!)")
            completion(true)
        }

        healthStore.execute(query)
    }
    
    func sendHealthDataToServer(heartRate: Double, steps: Double, completion: @escaping (Bool) -> Void) {
        // The URL of your Next.js API endpoint
        guard let url = URL(string: "http://localhost:3000/api/updateAppleHealthData") else {
            print("Invalid URL")
            completion(false)
            return
        }

        // The health data to send
        let healthData = ["heartRate": heartRate, "steps": steps] as [String: Any]

        // Convert the health data to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: healthData) else {
            print("Failed to serialize health data")
            completion(false)
            return
        }

        // Create a POST request with the JSON data
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Create a data task with the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send health data: \(error)")
                completion(false)
                return
            }

            if let data = data {
                // Handle the response data (e.g., print it out)
                print(String(data: data, encoding: .utf8)!)
                completion(true)
            } else {
                print("Did not receive any data")
                completion(false)
            }
        }

        // Start the data task
        task.resume()
    }
}
