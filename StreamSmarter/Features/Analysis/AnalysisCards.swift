import SwiftUI
import SwiftData

// MARK: - First Glance Card
struct FirstGlanceCard: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel // To access isServiceMatch and formatDuration

    @ViewBuilder
    var body: some View {
        let now = Date()
        let tenDaysFromNow = now.addingTimeInterval(10 * 24 * 60 * 60)
        
        let allActiveServices = (data.steadyServices + data.changeServices).unique(by: \.id)
        let expiringServices = allActiveServices.filter { $0.renewalDate <= tenDaysFromNow }

        VStack(alignment: .leading, spacing: 8) {
            // Monthly Budget header matching Android screen status
            Text("MONTHLY BUDGET: \(data.totalActiveCost.formatted(.currency(code: "USD")))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.popcornYellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)

            CardBackground(backgroundColor: .retroTVGray) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FIRST GLANCE (Renewing soon)")
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                
                if expiringServices.isEmpty {
                    Text("No services are renewing within the next 10 days.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    HStack(spacing: 8) {
                        LegendItem(color: .red, text: "Suspend This Service")
                        LegendItem(color: .yellow, text: "Under Utilized")
                        LegendItem(color: .green, text: "Utilized")
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // Table Header
                    HStack {
                        Text("Service").font(.caption.bold()).foregroundColor(.popcornYellow).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Cost").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                        Text("Watched").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                        Text("Ready").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                    }

                    let desiredHrs = Double(user?.streamingHoursPerMonth ?? 60)
                    let totalWatchedMinutesLast30 = data.historyByService.values.flatMap { $0 }.reduce(0) { $0 + ($1.runtime ?? 0) }
                    let totalWatchedHoursLast30 = Double(totalWatchedMinutesLast30) / 60.0

                    let sortedServices = expiringServices.sorted { s1, s2 in
                        let util1 = calculateUtilization(service: s1, data: data, desiredHrs: desiredHrs, totalWatchedHoursLast30: totalWatchedHoursLast30)
                        let util2 = calculateUtilization(service: s2, data: data, desiredHrs: desiredHrs, totalWatchedHoursLast30: totalWatchedHoursLast30)
                        return util1.colorValue < util2.colorValue
                    }

                    ForEach(sortedServices) { service in
                        let watchedItems = data.historyByService[service] ?? []
                        let watchedHrs = Double(watchedItems.reduce(0) { $0 + ($1.runtime ?? 0) }) / 60.0

                        let bingeItems = data.bingeByService[service] ?? []
                        let regularItems = data.regularPriorityByService[service] ?? []
                        let readyHrs = Double((bingeItems + regularItems).unique(by: \.id).reduce(0) { $0 + ($1.runtime ?? 0) }) / 60.0

                        let utilization = calculateUtilization(service: service, data: data, desiredHrs: desiredHrs, totalWatchedHoursLast30: totalWatchedHoursLast30)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(service.name).font(.caption.bold()).foregroundColor(utilization.color).frame(maxWidth: .infinity, alignment: .leading)
                                
                                if service.monthlyCost > 0 {
                                    Text(service.monthlyCost.formatted(.currency(code: "USD")))
                                        .font(.caption).foregroundColor(.white).frame(width: 60, alignment: .trailing)
                                } else {
                                    Text("Mkt: \(viewModel.getProjectedCost(for: service).formatted(.currency(code: "USD")))")
                                        .font(.system(size: 8)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
                                }
                                
                                Text(String(format: "%.1f h", watchedHrs)).font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                                Text(String(format: "%.1f h", readyHrs)).font(.caption).foregroundColor(.white).frame(width: 60, alignment: .trailing)
                            }
                            let costPerShow = watchedItems.isEmpty ? service.monthlyCost : service.monthlyCost / Double(watchedItems.count)
                            Text("Cost/show: \(costPerShow.formatted(.currency(code: "USD"))) (\(watchedItems.count))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        }
    }
    
    private func calculateUtilization(service: StreamingService, data: AnalysisResults, desiredHrs: Double, totalWatchedHoursLast30: Double) -> (color: Color, colorValue: Int) {
        let watchedItems = data.historyByService[service] ?? []
        let watchedHrs = Double(watchedItems.reduce(0) { $0 + ($1.runtime ?? 0) }) / 60.0
        
        let goalUtilization = desiredHrs > 0 ? watchedHrs / desiredHrs : 0.0
        let relativeUtilization = totalWatchedHoursLast30 > 0 ? watchedHrs / totalWatchedHoursLast30 : 0.0
        let bestUtilization = max(goalUtilization, relativeUtilization)
        
        if bestUtilization < 0.1 { return (.red, 0) }
        else if bestUtilization < 0.4 { return (.yellow, 1) }
        else { return (.green, 2) }
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Optimal Timeline Card
struct OptimalTimelineCard: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel

    var body: some View {
        let subscriptionLimit = user?.concurrentSubscriptionLimit ?? 2
        let timelineItems = data.optimalTimeline
        let totalActiveCost = data.totalActiveCost
        let optimizedTimelineCost = data.optimizedCost
        let potentialSavings = (totalActiveCost - optimizedTimelineCost).clamped(to: 0.0...Double.greatestFiniteMagnitude)
        
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Optimal 30-Day Timeline")
                    .font(.subheadline.bold())
                    .foregroundColor(.popcornYellow)
                Text("Optimized for up to \(subscriptionLimit) services based on your profile preference.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    CostRow(label: "Total Active Monthly Cost:", value: totalActiveCost, color: .white)
                    CostRow(label: "Optimized Timeline Cost:", value: optimizedTimelineCost, color: .green)
                    CostRow(label: "Potential Savings:", value: potentialSavings, color: .popcornYellow, isBold: true)
                }
                .padding(.vertical, 8)
                
                if timelineItems.isEmpty {
                    Text("No high priority shows match your current service constraints.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    TimelineGanttChart(timelineItems: timelineItems)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendation Summary:")
                        .font(.caption.bold())
                        .foregroundColor(.popcornYellow)
                    
                    let timelineServiceNames = timelineItems.compactMap { $0.bestService }.unique()
                    let servicesToSuspend = data.allManagementServices.filter { service in
                        service.isActive && 
                        !(service.monthlyCost > 0.0 && service.monthlyCost < 1.0) && 
                        !timelineServiceNames.contains { viewModel.isServiceMatch(serviceName: service.name, providers: $0) }
                    }
                    
                    if !servicesToSuspend.isEmpty {
                        Text("Suspend these to match optimal timeline:")
                            .font(.caption2)
                            .foregroundColor(.white)
                        
                        ForEach(servicesToSuspend) { service in
                            HStack(spacing: 4) {
                                Text("•")
                                Text(service.name)
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                        }
                    } else {
                        Text("Your current active services are optimal for your priority shows.")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

// MARK: - Project Timeline Card
struct ProjectTimelineCard: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel // To access isServiceMatch and formatDuration
    
    @State private var selectedServiceIds: [String: Bool] = [:]

    var body: some View {
        let allDbServices = viewModel.services.sorted { $0.name < $1.name }
        
        let timelineItems = calculateTimelineItems(
            watchlist: viewModel.watchlist,
            dailyHours: Double(user?.streamingHoursPerMonth ?? 60) / 30.0,
            allServices: viewModel.services,
            user: user,
            selectedServiceIds: selectedServiceIds
        )
        
        let totalActiveCost = data.totalActiveCost
        
        // Brainy dynamic calculation for the interactive timeline
        let optimizedTimelineCost = timelineItems.map { $0.bestService }.unique().reduce(0.0) { sum, serviceName in
            if let match = allDbServices.first(where: { $0.name == serviceName }) {
                return sum + viewModel.getProjectedCost(for: match)
            }
            return sum + (user?.mainViewingServiceCost ?? 0.0)
        }

        let potentialSavings = (totalActiveCost - optimizedTimelineCost).clamped(to: 0.0...Double.greatestFiniteMagnitude)
        
        return CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage/Create Your Own 30-Day Watching Timeline")
                    .font(.subheadline.bold())
                    .foregroundColor(.popcornYellow)
                Text("High Priority shows based on \(user?.streamingHoursPerMonth ?? 60) hrs/month. Shows don't need to be watched in specific order but watch higher priority shows first!")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    CostRow(label: "Total Active Monthly Cost:", value: totalActiveCost, color: .white)
                    CostRow(label: "Optimized Timeline Cost:", value: optimizedTimelineCost, color: .green)
                    CostRow(label: "Potential Savings:", value: potentialSavings, color: .popcornYellow, isBold: true)
                }
                .padding(.vertical, 8)
                
                if timelineItems.isEmpty {
                    Text("No high priority shows for selected services.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    TimelineGanttChart(timelineItems: timelineItems)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                Text("Choose Services:")
                    .font(.caption.bold())
                    .foregroundColor(.popcornYellow)
                Text("Customize selection and see how it impacts your timeline\nFor initial timeline, flashing active services should be suspended")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .italic()
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
                    ForEach(allDbServices, id: \.id) { service in
                        let isCheap = service.monthlyCost > 0.0 && service.monthlyCost < 1.0
                        let usedInTimeline = timelineItems.contains { item in
                            viewModel.isServiceMatch(serviceName: service.name, providers: item.bestService ?? "")
                        }
                        let shouldFlash = service.isActive && !isCheap && !usedInTimeline

                        ServiceSelectionToggle(
                            service: service,
                            isSelected: Binding(
                                get: { selectedServiceIds[service.id] ?? false },
                                set: { selectedServiceIds[service.id] = $0 }
                            ),
                            shouldFlash: shouldFlash,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
        .onAppear {
            // Initialize selectedServiceIds on appear
            if selectedServiceIds.isEmpty && !allDbServices.isEmpty {
                for service in allDbServices {
                    selectedServiceIds[service.id] = service.isActive
                }
            }
        }
    }
    
    // This function replicates the timeline calculation logic from AnalysisViewModel
    private func calculateTimelineItems(
        watchlist: [WatchlistItem],
        dailyHours: Double,
        allServices: [StreamingService],
        user: User?,
        selectedServiceIds: [String: Bool]
    ) -> [TimelineItem] {
        let highPriorityTopLevel = watchlist.filter {
            (($0.type == "movie" && $0.status == "Ready") || $0.type == "tv") && ($0.priority == 1 || $0.priority == 2)
        }
        
        let selectedServices = allServices.filter { selectedServiceIds[$0.id] ?? false }
        
        var timeline: [TimelineItem] = []
        var currentDayOffset = 0.0
        
        for item in highPriorityTopLevel.sorted(by: { $0.priority < $1.priority }) {
            guard let bestService = viewModel.determineBestService(item: item, availableServices: selectedServices) else { continue }
            
            let totalMinutes: Int
            if item.type == "movie" {
                totalMinutes = item.runtime ?? 0
            } else {
                totalMinutes = watchlist.filter {
                    $0.type == "episode" && $0.parentTmdbId == item.tmdbId && $0.status == "Ready"
                }.reduce(0) { $0 + ($1.runtime ?? 0) }
            }
            
            let runtime = Double(totalMinutes)
            if runtime > 0 {
                let hours = runtime / 60.0
                let daysNeeded = hours / max(0.5, dailyHours)
                let start = currentDayOffset
                let end = min(30.0, currentDayOffset + daysNeeded)
                
                if start < 30.0 {
                    timeline.append(TimelineItem(title: item.title, startDay: start, endDay: end, priority: item.priority, totalHours: hours, bestService: bestService))
                    currentDayOffset = end
                }
            }
        }
        return timeline
    }
}

struct ServiceSelectionToggle: View {
    let service: StreamingService
    @Binding var isSelected: Bool
    let shouldFlash: Bool
    let viewModel: AnalysisViewModel
    
    @State private var flashOpacity: Double = 1.0
    
    var body: some View {
        let costDisplay = service.monthlyCost > 0 
            ? service.monthlyCost.formatted(.currency(code: "USD")) 
            : "Mkt: \(viewModel.getProjectedCost(for: service).formatted(.currency(code: "USD")))"
            
        HStack(spacing: 8) {
            Checkbox(checked: $isSelected)
            Text("\(service.name) (\(costDisplay))")
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(service.isActive ? .green : Color(red: 1.0, green: 0.8, blue: 0.8)) // #FFCCCB
                .opacity(shouldFlash ? flashOpacity : 1.0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isSelected.toggle()
        }
        .onAppear { startFlashingIfNeeded() }
        .onChange(of: shouldFlash) { _, _ in startFlashingIfNeeded() }
    }
    
    private func startFlashingIfNeeded() {
        if shouldFlash {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                flashOpacity = 0.4
            }
        } else {
            withAnimation {
                flashOpacity = 1.0
            }
        }
    }
}

struct Checkbox: View {
    @Binding var checked: Bool
    
    var body: some View {
        Image(systemName: checked ? "checkmark.square.fill" : "square")
            .foregroundColor(checked ? .popcornYellow : .gray)
    }
}

struct CostRow: View {
    let label: String
    let value: Double
    let color: Color
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(color)
                .fontWeight(isBold ? .bold : .regular)
            Spacer()
            Text(value.formatted(.currency(code: "USD")))
                .font(.caption)
                .foregroundColor(color)
                .fontWeight(isBold ? .bold : .regular)
        }
    }
}

struct TimelineGanttChart: View {
    let timelineItems: [TimelineItem]
    
    var body: some View {
        let totalItemsAndHeadings = timelineItems.count + timelineItems.map { $0.priority }.unique().count
        let chartHeight: CGFloat = min(CGFloat(totalItemsAndHeadings * 35), 250)
        
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("Optimal Service")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .leading)
                Text("30-Day Timeline")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .background(Color.blue)
            
            Canvas { context, size in
                let serviceColumnWidth: CGFloat = 90
                let timelineWidth = size.width - serviceColumnWidth
                let dayWidth = timelineWidth / 30
                
                // Draw vertical grid lines
                for i in 0...30 where i % 5 == 0 {
                    let x = serviceColumnWidth + CGFloat(i) * dayWidth
                    context.stroke(Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }, with: .color(Color.white.opacity(0.1)), lineWidth: 1)
                }
                
                let barHeight: CGFloat = 12
                let headingHeight: CGFloat = 30
                let verticalSpacing: CGFloat = 8
                let paddingPx: CGFloat = 4
                
                var currentY: CGFloat = 0
                
                let groupedItems = timelineItems.groupedBy { $0.priority }.sorted { $0.key < $1.key }
                
                for (priority, items) in groupedItems {
                    let priorityLabelText = {
                        switch priority {
                        case 1: return "Must Watch Now"
                        case 2: return "Watch Soon"
                        default: return "Watch Later"
                        }
                    }()
                    
                    // Draw Priority Heading
                    let headingColor: Color = priority == 1 ? .green : .cyan
                    context.draw(Text(priorityLabelText)
                                    .font(.system(size: 11).bold())
                                    .underline()
                                    .foregroundColor(headingColor),
                                 at: CGPoint(x: serviceColumnWidth + paddingPx, y: currentY + headingHeight / 2),
                                 anchor: .leading)
                    currentY += headingHeight
                    
                    // Draw Timeline Bars
                    for item in items {
                        let top = currentY
                        if top + barHeight <= size.height {
                            let left = serviceColumnWidth + CGFloat(item.startDay) * dayWidth
                            let right = serviceColumnWidth + CGFloat(item.endDay) * dayWidth
                            let barWidth = max(4, right - left)
                            
                            // Draw Service Name
                            if let serviceName = item.bestService {
                                context.draw(Text(serviceName)
                                                .font(.system(size: 10))
                                                .foregroundColor(.popcornYellow),
                                             at: CGPoint(x: paddingPx, y: top + barHeight / 2),
                                             anchor: .leading)
                            }
                            
                            // Draw Bar
                            let barColor: Color = priority == 1 ? .green.opacity(0.7) : .cyan.opacity(0.7)
                            let barRect = CGRect(x: left, y: top, width: barWidth, height: barHeight)
                            context.fill(Path(roundedRect: barRect, cornerRadius: 4), with: .color(barColor))
                            
                            // Draw Item Title
                            let labelText = "\(item.title) (\(String(format: "%.1f", item.totalHours))h)"
                            let textMeasurement = context.resolve(Text(labelText).font(.system(size: 9)).foregroundColor(.white))
                            let textWidth = textMeasurement.measure(in: size).width
                            
                            let textTop = top + barHeight / 2
                            
                            let rightSpace = size.width - right
                            let leftSpace = left - serviceColumnWidth
                            
                            if rightSpace >= textWidth + paddingPx {
                                context.draw(Text(labelText).font(.system(size: 9)).foregroundColor(.white),
                                             at: CGPoint(x: right + paddingPx, y: textTop),
                                             anchor: .leading)
                            } else if leftSpace >= textWidth + paddingPx {
                                context.draw(Text(labelText).font(.system(size: 9)).foregroundColor(.white),
                                             at: CGPoint(x: left - paddingPx, y: textTop),
                                             anchor: .trailing)
                        } else {
                                context.draw(Text(labelText).font(.system(size: 9)).foregroundColor(.white),
                                             at: CGPoint(x: left + paddingPx, y: textTop),
                                             anchor: .leading)
                            }
                        }
                        currentY += barHeight + verticalSpacing
                    }
                    currentY += verticalSpacing
                }
            }
            .frame(height: chartHeight)
            .background(Color.retroGray)
        }
    }
}

// MARK: - Show Availability Matrix Card
struct ShowAvailabilityMatrixCard: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel
    
     @ViewBuilder
     var body: some View {
         let matrixServices = {
             var list = viewModel.services
             let mainName = user?.mainViewingService
             let mainInList = mainName != nil && list.contains(where: { viewModel.isServiceMatch(serviceName: mainName!, providers: $0.name) })
             
             if let main = mainName, !mainInList {
                 let virtualMain = StreamingService(
                     name: main,
                     startDate: Date(),
                     renewalDate: Date(),
                     monthlyCost: user?.mainViewingServiceCost ?? 0.0,
                     isActive: true
                 )
                 list.append(virtualMain)
             }
             
             return list.sorted { s1, s2 in
                 let isS1Main = mainName != nil && viewModel.isServiceMatch(serviceName: mainName!, providers: s1.name)
                 let isS2Main = mainName != nil && viewModel.isServiceMatch(serviceName: mainName!, providers: s2.name)
                 if isS1Main != isS2Main { return isS1Main }
                 return s1.name < s2.name
             }
         }()

         let priorityShows = viewModel.watchlist.filter {
             $0.status == "Ready" && ($0.type == "movie" || $0.type == "tv") && ($0.priority == 1 || $0.priority == 2)
         }
         .sorted { $0.priority < $1.priority || ($0.priority == $1.priority && $0.title < $1.title) }

         if !priorityShows.isEmpty && !matrixServices.isEmpty {
             CardBackground {
                 VStack(alignment: .leading, spacing: 12) {
                     Text("Show Availability Matrix")
                         .font(.subheadline.bold())
                         .foregroundColor(.popcornYellow)

                     VStack(alignment: .leading, spacing: 0) {
                         // Header Row (Services)
                         HStack(alignment: .bottom, spacing: 0) {
                             Text("")
                                 .frame(width: 100, alignment: .leading)
                             
                             ForEach(matrixServices) { service in
                                 let isMain = user?.mainViewingService != nil && viewModel.isServiceMatch(serviceName: user!.mainViewingService!, providers: service.name)
                                 
                                 Text(service.name)
                                     .font(.system(size: 8))
                                     .foregroundColor(isMain ? .popcornYellow : .white)
                                     .lineLimit(1)
                                     .fixedSize()
                                     .rotationEffect(.degrees(-90), anchor: .leading)
                                     .frame(width: 13, height: 100, alignment: .bottomLeading)
                                     .offset(x: 5) // Corrects for the font width to center it over the 13pt column
                                     .padding(.bottom, 2)
                             }
                         }
                         
                         // Grid Rows (Shows)
                         ForEach(priorityShows) { show in
                             Divider().background(Color.white.opacity(0.1))
                             HStack(alignment: .center, spacing: 0) {
                                 Text(show.title)
                                     .font(.system(size: 9))
                                     .foregroundColor(show.priority == 1 ? .popcornYellow : .white)
                                     .lineLimit(1)
                                     .truncationMode(.tail)
                                     .frame(width: 100, alignment: .leading)
                                 
                                 ForEach(matrixServices) { service in
                                     let isAvailable = viewModel.isServiceMatch(serviceName: service.name, providers: show.providers ?? "")
                                     
                                     ZStack {
                                         Circle()
                                             .fill(isAvailable ? Color.brandBlue : Color.white.opacity(0.15))
                                             .frame(width: isAvailable ? 6 : 2, height: isAvailable ? 6 : 2)
                                     }
                                     .frame(width: 13, height: 20)
                                 }
                             }
                         }
                     }
                 }
             }
         }
     }
 }

// MARK: - High Priority Service Card (Deep Dives)
struct HighPriorityServiceCard: View {
    let service: StreamingService
    let items: [WatchlistItem]
    let allWatchlist: [WatchlistItem]
    let accentColor: Color
    let viewModel: AnalysisViewModel
    
    @State private var isExpanded = false
    
    var body: some View {
        let totalDuration = items.reduce(0) { $0 + ($1.runtime ?? 0) }
        
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name)
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            
                            Text("Renews: \(service.renewalDate, style: .date)")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                            
                            Text("Total Time: \(viewModel.formatDuration(totalDuration)) • \(items.count) Items")
                                .font(.caption.bold())
                                .foregroundColor(accentColor)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Movies Section
                        let movies = items.filter { $0.type == "movie" }
                        ForEach(movies) { movie in
                            HStack {
                                Text("• \(movie.title) (Movie)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(viewModel.formatDuration(movie.runtime ?? 0))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Shows Section
                        let episodesByShow = Dictionary(grouping: items.filter { $0.type == "episode" }, by: { $0.parentTmdbId })
                        ForEach(episodesByShow.keys.compactMap { $0 }.sorted(), id: \.self) { showId in
                            if let showEps = episodesByShow[showId] {
                                HighPriorityShowSection(showId: showId, episodes: showEps, watchlist: allWatchlist, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HighPriorityShowSection: View {
    let showId: Int?
    let episodes: [WatchlistItem]
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    @State private var isExpanded = false
    
    var body: some View {
        let show = watchlist.first { $0.type == "tv" && $0.tmdbId == showId }
        let showTitle = show?.title ?? "Unknown Show"
        let totalDuration = episodes.reduce(0) { $0 + ($1.runtime ?? 0) }
        
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("• \(showTitle)")
                        .font(.caption.bold())
                        .foregroundColor(.popcornYellow)
                    Text("(\(viewModel.formatDuration(totalDuration)))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.popcornYellow)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                let episodesBySeason = Dictionary(grouping: episodes, by: { $0.seasonNumber })
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(episodesBySeason.keys.sorted(), id: \.self) { seasonNum in
                        if let seasonEps = episodesBySeason[seasonNum] {
                            HighPrioritySeasonSection(seasonNum: seasonNum, episodes: seasonEps, viewModel: viewModel)
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }
}

struct HighPrioritySeasonSection: View {
    let seasonNum: Int
    let episodes: [WatchlistItem]
    let viewModel: AnalysisViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Season \(seasonNum) (\(viewModel.formatDuration(episodes.reduce(0) { $0 + ($1.runtime ?? 0) })))")
                .font(.system(size: 10).bold())
                .foregroundColor(.gray)
            
            ForEach(episodes) { ep in
                HStack {
                    Text("E\(ep.episodeNumber): \(ep.title)")
                    Spacer()
                    Text("\(ep.runtime ?? 0)m")
                }
                .font(.system(size: 9))
                .foregroundColor(.white)
                .padding(.leading, 8)
            }
        }
    }
}

// MARK: - History & Audit Cards

struct RecentWatchAuditCard: View {
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    
    var body: some View {
        let recentWatched = watchlist.filter { $0.status == "Watched" && ($0.type == "movie" || $0.type == "episode") }
            .sorted(by: { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) })
            .prefix(15)
        
        if !recentWatched.isEmpty {
            let hasLowPriority = recentWatched.contains(where: { $0.priority >= 3 })
            
            CardBackground {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Watch Audit (Last 15)")
                        .font(.subheadline.bold())
                        .foregroundColor(.popcornYellow)
                    
                    if hasLowPriority {
                        Text("Note: Focus on High Priority (1-2) shows first or adjust show priorities.")
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recentWatched) { item in
                            let isLowPriority = item.priority >= 3
                            let displayTitle = viewModel.getDisplayTitle(for: item, in: watchlist)
                            
                            HStack {
                                Text("• \(displayTitle)")
                                    .font(.caption)
                                    .foregroundColor(isLowPriority ? .red : .white)
                                    .lineLimit(1)
                                Spacer()
                                Text("Pri: \(item.priority)")
                                    .font(.caption2)
                                    .foregroundColor(isLowPriority ? .red : .cyan)
                            }
                            .padding(4)
                            .background(isLowPriority ? Color.red.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
}

struct ServiceHistoryCard: View {
    let service: StreamingService
    let items: [WatchlistItem]
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    @State private var isExpanded = false
    
    var body: some View {
        let totalMinutes = items.reduce(0) { $0 + ($1.runtime ?? 0) }
        
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Button { withAnimation { isExpanded.toggle() } } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name).font(.headline.bold()).foregroundColor(.white)
                            Text("Total Time: \(viewModel.formatDuration(totalMinutes)) (\(items.count) items)")
                                .font(.caption).foregroundColor(.popcornYellow)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.white)
                    }
                }.buttonStyle(.plain)
                
                if isExpanded {
                    Divider().background(Color.white.opacity(0.2))
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items) { item in
                            HStack {
                                Text("• \(viewModel.getDisplayTitle(for: item, in: watchlist))")
                                    .font(.caption).foregroundColor(.white).lineLimit(1)
                                Spacer()
                                Text("\(item.runtime ?? 0)m").font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MonthlyHistoryTableCard: View {
    let monthlyHistory: [MonthHistory]
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    @State private var selectedMonth: MonthHistory?
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Month").font(.caption.bold()).foregroundColor(.popcornYellow).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Hours Watched").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 100, alignment: .trailing)
                }
                Divider().background(Color.white.opacity(0.2))
                
                ForEach(monthlyHistory) { month in
                    Button { selectedMonth = month } label: {
                        HStack {
                            Text("\(month.monthName) \(String(month.year))")
                                .font(.caption).foregroundColor(.white)
                            Spacer()
                            let hrs = Double(month.items.reduce(0) { $0 + ($1.runtime ?? 0) }) / 60.0
                            Text(String(format: "%.1f hrs", hrs))
                                .font(.caption).foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                    }.buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedMonth) { month in
            NavigationStack {
                List {
                    Section(header: Text("Watched Items").foregroundColor(.popcornYellow)) {
                        ForEach(month.items) { item in
                            HStack {
                                Text(viewModel.getDisplayTitle(for: item, in: watchlist))
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.runtime ?? 0)m")
                                    .font(.caption).foregroundColor(.gray)
                            }
                        }
                    }
                    
                }
                .navigationTitle("\(month.monthName) \(String(month.year)) History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { selectedMonth = nil }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
    }
}

struct MainServiceDuplicatesCard: View {
    let user: User?
    let data: AnalysisResults
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Available on Main Service & Others")
                    .font(.subheadline.bold()).foregroundColor(.popcornYellow)
                
                if let mainName = user?.mainViewingService, !mainName.isEmpty {
                    let allOtherServices = viewModel.services.filter { !viewModel.isServiceMatch(serviceName: mainName, providers: $0.name) }
                    let duplicates = watchlist.filter { $0.status == "Ready" && ($0.type == "movie" || $0.type == "tv") }
                        .compactMap { item -> (WatchlistItem, [StreamingService])? in
                            let providers = item.providers ?? ""
                            if viewModel.isServiceMatch(serviceName: mainName, providers: providers) {
                                let others = allOtherServices.filter { other in viewModel.isServiceMatch(serviceName: other.name, providers: providers) }
                                return !others.isEmpty ? (item, others) : nil
                            }
                            return nil
                        }

                    Text("These are on \(mainName) AND another service (active or not):")
                        .font(.caption2).foregroundColor(.gray)

                    if duplicates.isEmpty {
                        Text("No current redundancies found in your 'Ready' watchlist.")
                            .font(.caption2).italic().foregroundColor(.gray)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(duplicates, id: \.0.id) { (item, others) in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("• \(item.title)").font(.caption).bold().foregroundColor(.white)
                                    Text("  Also on: \(others.map { $0.name }.joined(separator: ", "))")
                                        .font(.system(size: 9)).foregroundColor(.cyan)
                                }
                            }
                        }
                    }
                } else {
                    Text("Please set a 'Main Viewing Service' in your Profile to audit content redundancies.")
                        .font(.caption2).italic().foregroundColor(.gray)
                }
            }
        }
    }
}

struct MultipleActiveServiceShowsCard: View {
    let data: AnalysisResults
    let viewModel: AnalysisViewModel

    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shows on Multiple Active Services")
                    .font(.subheadline.bold()).foregroundColor(.popcornYellow)
                
                if data.multipleActiveServiceShows.isEmpty {
                    Text("No shows found that are currently 'Ready' and available on more than one active streaming service. This section helps identify potential redundancies in your active subscriptions.")
                        .font(.caption2).italic().foregroundColor(.gray)
                } else {
                    Text("These 'Ready' shows are available on more than one of your currently active services:")
                        .font(.caption2).foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(data.multipleActiveServiceShows, id: \.0.id) { (item, services) in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(item.title)").font(.caption).bold().foregroundColor(.white)
                                Text("  Available on: \(services.map { $0.name }.joined(separator: ", "))")
                                    .font(.system(size: 9)).foregroundColor(.cyan)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DuplicateShowCard: View {
    let showTitle: String
    let providerList: String
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 4) {
                Text(showTitle).font(.caption.bold()).foregroundColor(.white)
                Text("Available on multiple active services:").font(.system(size: 9)).foregroundColor(.popcornYellow)
                Text("• \(providerList)").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Options to Consider Cards

struct SummaryCard: View {
    let user: User?
    let data: AnalysisResults
    let viewModel: AnalysisViewModel
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Steady as she goes")
                    .font(.subheadline.bold())
                    .foregroundColor(.green)
                Text("(Make no services switches at this time.)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Divider().background(Color.white.opacity(0.2))
                
                let streamingHoursLimit = user?.streamingHoursPerMonth ?? 60
                let totalReadyHours = Double(data.totalReadyMinutes) / 60.0
                
                if totalReadyHours >= Double(streamingHoursLimit) {
                    Text("There are plenty of high priority shows to watch on active services over the next month based on your streaming hours per month (\(streamingHoursLimit) hrs) and your high priority shows Ready to watch. Suspend services beyond your set hours per month since you won't get to them.")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("Not enough high priority shows on the watch list for currently active services (\(String(format: "%.1f", totalReadyHours)) hrs found vs \(streamingHoursLimit) hrs desired). You might want to add more high priority shows or update existing shows to watch to priority 1 or 2. OR CONSIDER A CHANGE OR SUSPEND A SERVICE.")
                        .font(.caption)
                        .foregroundColor(.popcornYellow)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                let displayedServices = data.allManagementServices.filter { !$0.name.contains("(Main Service)") }
                
                if displayedServices.isEmpty {
                    Text("No services meeting criteria.").font(.caption).foregroundColor(.gray)
                } else {
                    HStack {
                        Text("Service").font(.caption.bold()).foregroundColor(.popcornYellow).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Watched").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                        Text("Ready").font(.caption.bold()).foregroundColor(.popcornYellow).frame(width: 60, alignment: .trailing)
                    }
                    
                    ForEach(sortServicesByReadyTime(displayedServices)) { service in
                        let watchedMinutes = (data.historyByService[service] ?? []).reduce(0) { $0 + ($1.runtime ?? 0) }
                        let readyMinutes = (data.bingeByService[service] ?? []).reduce(0) { $0 + ($1.runtime ?? 0) } + (data.regularPriorityByService[service] ?? []).reduce(0) { $0 + ($1.runtime ?? 0) }
                        
                        HStack {
                            Text(service.name).font(.caption).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%.1f hrs", Double(watchedMinutes) / 60.0)).font(.caption).foregroundColor(.white).frame(width: 60, alignment: .trailing)
                            Text(String(format: "%.1f hrs", Double(readyMinutes) / 60.0)).font(.caption).foregroundColor(.white).frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func sortServicesByReadyTime(_ services: [StreamingService]) -> [StreamingService] {
        services.sorted { s1, s2 in
            calculateReadyMinutes(for: s1) > calculateReadyMinutes(for: s2)
        }
    }

    private func calculateReadyMinutes(for service: StreamingService) -> Int {
        let binge = (data.bingeByService[service] ?? []).reduce(0) { $0 + ($1.runtime ?? 0) }
        let regular = (data.regularPriorityByService[service] ?? []).reduce(0) { $0 + ($1.runtime ?? 0) }
        return binge + regular
    }
}

struct WindsOfChangeCard: View {
    let user: User?
    let data: AnalysisResults
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("Winds of Change")
                    .font(.subheadline.bold())
                    .foregroundColor(.popcornYellow)
                Text("(Consider service changes)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Divider().background(Color.white.opacity(0.2))
                
                if let u = user {
                    Text("Desired Concurrent Subscriptions: \(u.concurrentSubscriptionLimit)")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    Text("Streaming Hours Per Month: \(u.streamingHoursPerMonth) hrs")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                
                let bingeServices = data.bingeByService.keys.filter { !$0.name.contains("(Main Service)") }
                if !bingeServices.isEmpty {
                    Text("Recommendation:")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("You have services expiring soon. Suspend now and finish binging:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(bingeServices) { service in
                        Text("• Suspend \(service.name) (Renews: \(service.renewalDate, style: .date))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                if !data.suspendedHighPriority.isEmpty {
                    Text("Replace by activating service(s) with high priority shows:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(data.suspendedHighPriority) { service in
                        let serviceItems = data.highPriorityReady.filter { viewModel.isServiceMatch(serviceName: service.name, providers: $0.providers ?? "") }
                        let totalDuration = serviceItems.reduce(0) { $0 + ($1.runtime ?? 0) }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• Activate \(service.name) (\(viewModel.formatDuration(totalDuration)) ready)")
                                .font(.caption)
                                .foregroundColor(.white)
                            ForEach(serviceItems.filter { $0.type == "movie" }) { movie in
                                Text("  - \(movie.title) (Movie)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            ForEach(getUniqueShowIds(from: serviceItems), id: \.self) { showId in
                                if let show = watchlist.first(where: { $0.type == "tv" && $0.tmdbId == showId }) {
                                    Text("  - \(show.title) (Series)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                } else if bingeServices.isEmpty && data.changeServices.isEmpty {
                    Text("Your subscriptions are well-utilized!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if !data.changeServices.isEmpty {
                    Text("These active services have low utilization. Consider suspending:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(data.changeServices) { service in
                        Text("• \(service.name) (Renews: \(service.renewalDate, style: .date))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func getUniqueShowIds(from items: [WatchlistItem]) -> [Int] {
        items.filter { $0.type == "episode" }
            .map { $0.parentTmdbId }
            .unique()
            .compactMap { $0 }
            .sorted()
    }
}

struct DetoxCard: View {
    let data: AnalysisResults
    let watchlist: [WatchlistItem]
    let viewModel: AnalysisViewModel
    
    var body: some View {
        CardBackground {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Detox")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("(Fresh Start, Cold turkey! Crazy, right?)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Divider().background(Color.white.opacity(0.2))
                
                Text("Consider suspending all your services, temporarily. Continue binging until renewal dates. Then...watch free services, read a book, save money... Update your watch list and show priorities. And then, on your time, when you're ready, begin anew.")
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineSpacing(2)
                
                let sortedFreeServices = data.freeItemsByService.keys.sorted(by: { $0.name < $1.name })
                if !sortedFreeServices.isEmpty {
                    Text("Available on Free Services:")
                        .font(.caption.bold())
                        .foregroundColor(.popcornYellow)
                        .padding(.top, 8)
                    
                    ForEach(sortedFreeServices) { service in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name)
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                            ForEach(data.freeItemsByService[service] ?? []) { item in
                                let duration = calculateItemDuration(item)
                                let durationText = duration > 0 ? " (\(viewModel.formatDuration(duration)))" : ""
                                Text("• \(item.title)\(durationText) (Pri: \(item.priority))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    private func calculateItemDuration(_ item: WatchlistItem) -> Int {
        if item.type == "movie" {
            return item.runtime ?? 0
        } else {
            return watchlist.filter {
                $0.type == "episode" &&
                $0.parentTmdbId == item.tmdbId &&
                $0.status == "Ready"
            }.reduce(0) { $0 + ($1.runtime ?? 0) }
        }
    }
}

// MARK: - Reusable Card Background
struct CardBackground<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    
    init(backgroundColor: Color = .retroGray, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Extensions for convenience
extension Array where Element: Identifiable {
    func unique(by idKeyPath: KeyPath<Element, Element.ID>) -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0[keyPath: idKeyPath]).inserted }
    }
}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Dictionary where Key: Hashable, Value: Sequence {
    func groupedBy<GroupKey: Hashable>(_ keySelector: (Value.Element) -> GroupKey) -> [GroupKey: [Value.Element]] {
        var result: [GroupKey: [Value.Element]] = [:]
        for (_, valueSequence) in self {
            for element in valueSequence {
                let key = keySelector(element)
                result[key, default: []].append(element)
            }
        }
        return result
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(self, range.upperBound))
    }
}