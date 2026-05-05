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
    
    let allOptions = [
        "Amazon Prime", "Apple TV", "Crunchyroll", "Discovery+", "Disney+", "ESPN+",
        "HBO Max", "Hulu", "Netflix", "Paramount+", "Peacock", "Philo", 
        "Britbox", "Acorn TV", "AMC+", "Starz"
    ].sorted()

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Details") {
                    if service == nil {
                        Picker("Service Name", selection: $name) {
                            ForEach(allOptions, id: \.self) { Text($0) }
                        }
                    } else {
                        Text(service?.name ?? "").bold()
                    }
                    TextField("Monthly Cost ($)", text: $cost).keyboardType(.decimalPad)
                }
                
                Section("Dates & Status") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Renewal Date", selection: $renewalDate, displayedComponents: .date)
                    Toggle("Is Active", isOn: $isActive)
                }
            }
            .navigationTitle(service == nil ? "Add Subscription" : "Edit Subscription")
            .toolbar {
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
                } else { name = allOptions.first ?? "" }
            }
        }
    }
    
    private func save() {
        let costVal = Double(cost) ?? 0.0
        if let service {
            viewModel.updateService(service, name: name, start: startDate, renew: renewalDate, cost: costVal, active: isActive)
        } else {
            viewModel.addService(name: name, start: startDate, renew: renewalDate, cost: costVal, active: isActive)
        }
    }
}
