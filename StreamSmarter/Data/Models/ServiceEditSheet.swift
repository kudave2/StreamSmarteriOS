import SwiftUI

struct ServiceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: SubscriptionsViewModel
    var service: StreamingService? = nil
    
    @State private var name: String = ""
    @State private var cost: String = ""
    @State private var startDate = Date()
    @State private var renewalDate = Date()
    @State private var isActive = true
    
    var isSharedOrFree: Bool {
        let costVal = Double(cost) ?? 0.0
        return costVal > 0.0 && costVal < 1.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Details") {
                    if service == nil {
                        Picker("Service Name", selection: $name) {
                            ForEach(viewModel.allServiceOptions, id: \.self) { Text($0) }
                        }
                    } else {
                        Text(service?.name ?? "").bold()
                    }
                    TextField("Monthly Cost ($)", text: $cost).keyboardType(.decimalPad)
                        .onChange(of: cost) { oldValue, newValue in
                            let costVal = Double(newValue) ?? 0.0
                            if costVal > 0.0 && costVal < 1.0 {
                                isActive = true
                            }
                        }
                }
                
                Section("Dates & Status") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Renewal Date", selection: $renewalDate, displayedComponents: .date)
                    
                    if isSharedOrFree {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Shared/Free")
                                .foregroundColor(.gray)
                        }
                    } else {
                        Toggle("Is Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(service == nil ? "Add Subscription" : "Edit Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let service {
                    name = service.name
                    cost = String(format: "%.2f", service.monthlyCost)
                    startDate = service.startDate
                    renewalDate = service.renewalDate
                    isActive = service.isActive
                } else { name = viewModel.allServiceOptions.first ?? "" }
            }
        }
    }
    
    private func save() {
        let costVal = Double(cost) ?? 0.0
        let finalActive = isSharedOrFree ? true : isActive
        
        // Always update since all services are pre-created
        if let service = service {
            viewModel.updateService(service, name: name, start: startDate, renew: renewalDate, cost: costVal, active: finalActive)
        } else {
            // Find the service by name from the pre-created list and update it
            if let existingService = viewModel.services.first(where: { $0.name == name }) {
                viewModel.updateService(existingService, name: name, start: startDate, renew: renewalDate, cost: costVal, active: finalActive)
            }
        }
    }
}
