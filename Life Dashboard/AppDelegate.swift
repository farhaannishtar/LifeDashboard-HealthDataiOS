import UIKit
import BackgroundTasks
import HealthKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "Life-Dashboard.Life-Dashboard.fetchHealthData", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background")
        scheduleAppRefresh()
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "Life-Dashboard.Life-Dashboard.fetchHealthData")
        request.earliestBeginDate = nil // Eligible to run immediately

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Add this line:
        print("Handling background fetch...")
        
        // Schedule a new refresh task
        scheduleAppRefresh()
        
        // Create an operation that performs the main part of the background task
        let operation = BlockOperation {
            HealthKitManager.shared.fetchLatestHealthData { success in
                task.setTaskCompleted(success: success)
            }
        }
        
        // Create a new background task operation and add it to the operation queue
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation(operation)
    }
}
