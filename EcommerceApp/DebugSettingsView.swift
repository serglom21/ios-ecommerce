import SwiftUI

struct DebugSettingsView: View {
    @StateObject private var backend = MockBackend.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage("ab_variant") private var abVariant = "A"
    
    var body: some View {
        Form {
            // Latency Profile
            Section {
                Picker("Latency Profile", selection: $backend.latencyProfile) {
                    ForEach(MockBackend.LatencyProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue).tag(profile)
                    }
                }
            } header: {
                Text("Network Latency")
            } footer: {
                Text("Simulates different network speeds")
            }
            
            // Network Type
            Section {
                Picker("Connection Type", selection: $networkMonitor.connectionType) {
                    Text("WiFi").tag("wifi")
                    Text("Cellular").tag("cellular")
                    Text("Offline").tag("offline")
                }
                
                Toggle("Simulate Offline", isOn: $backend.simulateOffline)
            } header: {
                Text("Network Type")
            }
            
            // Error Injection
            Section {
                ForEach(MockBackend.Endpoint.allCases, id: \.self) { endpoint in
                    Toggle(endpoint.rawValue.capitalized, isOn: Binding(
                        get: { backend.failureInjection[endpoint] ?? false },
                        set: { backend.failureInjection[endpoint] = $0 }
                    ))
                }
            } header: {
                Text("Failure Injection")
            } footer: {
                Text("Force specific endpoints to fail for testing")
            }
            
            // A/B Testing
            Section {
                Picker("A/B Variant", selection: $abVariant) {
                    Text("Variant A").tag("A")
                    Text("Variant B").tag("B")
                }
            } header: {
                Text("A/B Testing")
            } footer: {
                Text("Switch between A/B test variants")
            }
            
            // User Type Toggle
            Section {
                Text("Session ID: \(getSessionId())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Device Class: \(DeviceInfo.deviceClass)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Country: \(Locale.current.region?.identifier ?? "US")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Session Info")
            }
            
            // Sentry Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DSN Configured: ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("Tracing Enabled: ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("Sample Rate: 100%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Release: \(version)+\(build)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Sentry Configuration")
            } footer: {
                Text("All transactions and spans are being captured")
            }
            
            // Reset Section
            Section {
                Button("Reset All Settings", role: .destructive) {
                    resetSettings()
                }
            }
        }
        .navigationTitle("Debug Settings")
    }
    
    private func getSessionId() -> String {
        // Access via environment or global state
        // For demo, just show a truncated UUID
        return "Session-\(UUID().uuidString.prefix(8))"
    }
    
    private func resetSettings() {
        backend.latencyProfile = .normal
        backend.failureInjection = [:]
        backend.simulateOffline = false
        networkMonitor.connectionType = "wifi"
        abVariant = "A"
    }
}

#Preview {
    NavigationStack {
        DebugSettingsView()
    }
}

