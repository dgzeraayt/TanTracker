import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sola_data.json")

        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData()
        }
    }

    // MARK: persistance (debounce léger)
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = data
        let work = DispatchWorkItem { [fileURL] in
            if let raw = try? JSONEncoder().encode(snapshot) {
                try? raw.write(to: fileURL, options: .atomic)
            }
        }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        if let raw = try? JSONEncoder().encode(data) { try? raw.write(to: fileURL, options: .atomic) }
    }

    var profile: UserProfile {
        get { data.profile }
        set { data.profile = newValue }
    }

    // MARK: - Onboarding lifecycle
    func finalizeOnboarding() {
        data.profile.phototype = PhototypeScoring.compute(from: data.profile)
        // indice de départ : issu de l'analyse photo si dispo, sinon de la teinte déclarée
        if let m = latestMetrics {
            data.profile.baselineIndex = m.tan
        } else {
            data.profile.baselineIndex = 35 + data.profile.startTanLevel * 8
        }
        data.profile.planStartDate = .now
        data.onboardingComplete = true
        saveNow()
    }

    /// Dernières métriques d'analyse réelles (depuis la photo la plus récente analysée).
    var latestMetrics: SkinMetrics? {
        data.sessions.last { $0.metrics != nil }?.metrics
    }
    /// Date de la dernière analyse photo (sert de point de départ à la progression).
    var latestMetricsDate: Date? {
        data.sessions.last { $0.metrics != nil }?.date
    }

    // MARK: - Quotas (offre gratuite vs SOLA+)
    static let freeAnalysisLimit = 2
    static let freePhotoLimit = 3
    var analysisCount: Int { data.sessions.filter { $0.metrics != nil }.count }
    var photoCount: Int { data.sessions.filter { $0.photoFilename != nil }.count }

    /// Une exposition (durée > 0) a-t-elle été enregistrée aujourd'hui ?
    var todayHasExposure: Bool {
        data.sessions.contains { $0.durationMinutes > 0 && Calendar.current.isDateInToday($0.date) }
    }

    /// Indice de départ prévisionnel pendant l'onboarding (avant finalisation).
    var previewBaseline: Int {
        latestMetrics?.tan ?? (35 + data.profile.startTanLevel * 8)
    }

    func resetAll() {
        data = AppData()
        saveNow()
    }

    func restartOnboarding() {
        data.onboardingComplete = false
        saveNow()
    }

    // MARK: - Indice de bronzage
    /// Indice courant : teinte mesurée la plus récente (ou base déclarée) + progression
    /// des expositions postérieures à cette mesure.
    var currentTanIndex: Int {
        let base = latestMetrics?.tan ?? profile.baselineIndex
        return min(100, base + sessionsContribution)
    }

    /// Chaque minute d'exposition sûre fait progresser légèrement l'indice (plafonné).
    /// On ne compte que les expositions postérieures à la dernière analyse photo,
    /// pour ne pas comptabiliser deux fois ce que la mesure reflète déjà.
    private var sessionsContribution: Int {
        let since = latestMetricsDate
        let totalMinutes = data.sessions
            .filter { since == nil || $0.date > since! }
            .reduce(0) { $0 + $1.durationMinutes }
        // ~1 point tous les 8 min cumulées, plafonné à 60 points
        return min(60, totalMinutes / 8)
    }

    var tanLevelLabel: String {
        switch currentTanIndex {
        case ..<35: return "Niveau 1"
        case ..<55: return "Niveau 2"
        case ..<75: return "Niveau 3"
        case ..<90: return "Niveau 4"
        default:    return "Niveau 5"
        }
    }

    var planProgress: Double {
        let weeks = Calendar.current.dateComponents([.weekOfYear],
                    from: profile.planStartDate, to: .now).weekOfYear ?? 0
        return min(1, Double(max(0, weeks)) / Double(profile.targetWeeks))
    }
    var currentWeek: Int {
        let weeks = (Calendar.current.dateComponents([.weekOfYear],
                    from: profile.planStartDate, to: .now).weekOfYear ?? 0) + 1
        return min(profile.targetWeeks, max(1, weeks))
    }

    /// Série de jours consécutifs avec au moins une action (session ou routine).
    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        var count = 0
        let activeDays = Set(data.sessions.map { cal.startOfDay(for: $0.date) })
            .union(data.routineDays.filter { !$0.completed.isEmpty }.compactMap { Self.dateFromKey($0.dayKey) })
        // tolère que la série démarre aujourd'hui ou hier
        if !activeDays.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while activeDays.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    /// 7 dernières valeurs hebdomadaires de l'indice (pour le graphique du journal).
    /// Série réelle : à chaque semaine, on part de la dernière teinte mesurée connue
    /// à cette date et on ajoute la progression des expositions cumulées.
    var weeklySeries: [Double] {
        let cal = Calendar.current
        var result: [Double] = []
        for w in stride(from: 6, through: 0, by: -1) {
            guard let weekEnd = cal.date(byAdding: .weekOfYear, value: -w, to: .now) else { continue }
            let baseAt = data.sessions
                .last { $0.metrics != nil && $0.date <= weekEnd }?
                .metrics?.tan ?? profile.baselineIndex
            let minutes = data.sessions
                .filter { $0.date <= weekEnd }
                .reduce(0) { $0 + $1.durationMinutes }
            let idx = min(100, baseAt + min(60, minutes / 8))
            result.append(Double(idx))
        }
        return result
    }

    // MARK: - Routine du jour
    static func dayKey(_ date: Date = .now) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func dateFromKey(_ key: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: key)
    }

    func todayRoutine() -> RoutineDay {
        let key = Self.dayKey()
        return data.routineDays.first { $0.dayKey == key } ?? RoutineDay(dayKey: key)
    }

    func toggleRoutine(_ step: Int) {
        let key = Self.dayKey()
        if let i = data.routineDays.firstIndex(where: { $0.dayKey == key }) {
            if data.routineDays[i].completed.contains(step) { data.routineDays[i].completed.remove(step) }
            else { data.routineDays[i].completed.insert(step) }
        } else {
            data.routineDays.append(RoutineDay(dayKey: key, completed: [step]))
        }
    }

    func isRoutineDone(_ step: Int) -> Bool { todayRoutine().completed.contains(step) }

    // MARK: - Sessions
    func addSession(_ s: TanSession) {
        data.sessions.append(s)
        saveNow()
    }

    func updateMetrics(_ metrics: SkinMetrics, forPhoto filename: String) {
        guard let i = data.sessions.lastIndex(where: { $0.photoFilename == filename }) else { return }
        data.sessions[i].metrics = metrics
        saveNow()
    }

    var lastPhotoSessions: [TanSession] {
        data.sessions.filter { $0.photoFilename != nil }.sorted { $0.date < $1.date }
    }

    // MARK: - Dose sûre du jour (selon phototype + UV)
    /// Minutes d'exposition sûres pour un indice UV donné.
    func safeMinutes(uv: Double) -> Int {
        guard uv > 0 else { return profile.phototype.safeMinutesAtUV8 * 2 }
        let scaled = Double(profile.phototype.safeMinutesAtUV8) * (8.0 / uv)
        return max(5, Int(scaled.rounded()))
    }
}
