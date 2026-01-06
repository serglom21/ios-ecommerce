import SwiftUI
import Sentry

@main
struct EcommerceAppApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // SENTRY INITIALIZATION: Configure SDK with tracing enabled
        SentrySDK.start { options in
            options.dsn = "https://examplePublicKey@o0.ingest.sentry.io/0" // Replace with your DSN
            options.environment = "dev"
            
            // Performance monitoring: sample 100% in dev
            options.tracesSampleRate = 1.0
            
            // Enable automatic performance instrumentation
            options.enableAutoPerformanceTracing = true
            options.enableFileIOTracing = true
            options.enableCoreDataTracing = true
            options.enableUserInteractionTracing = true
            
            // Set release version from bundle
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version)+\(build)"
            }
            
            // Attach build number for better trace filtering
            options.beforeSend = { event in
                if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    event.extra?["build"] = build
                }
                return event
            }
        }
        
        // SENTRY INSTRUMENTATION: Track cold app startup
        let startupSpan = SentryInstrumentation.startTransaction(
            name: "app.startup",
            operation: "app.startup"
        )
        SentryInstrumentation.setCommonContext(startupSpan)
        startupSpan.setData(value: "cold", key: "app.startup_type")
        
        // Simulate initialization work
        Thread.sleep(forTimeInterval: 0.05)
        
        startupSpan.finish(status: .ok)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Set user context (no PII - just user type)
                    SentrySDK.configureScope { scope in
                        let user = User()
                        user.data = [
                            "type": appState.isLoggedIn ? "logged_in" : "guest"
                        ]
                        scope.setUser(user)
                        
                        // Set session context
                        scope.setContext(value: [
                            "session_id": appState.sessionId.uuidString,
                            "country": Locale.current.region?.identifier ?? "US",
                            "device_class": DeviceInfo.deviceClass,
                            "network_type": NetworkMonitor.shared.connectionType
                        ], key: "app")
                    }
                }
        }
    }
}

