import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateService: NSObject, ObservableObject {
    enum Channel: String, CaseIterable, Identifiable {
        case stable
        case beta

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .stable: "Stable"
            case .beta: "Beta"
            }
        }
    }

    @Published var channel: Channel {
        didSet {
            UserDefaults.standard.set(channel.rawValue, forKey: Keys.channel)
            availableUpdateVersion = nil
            updaterDelegate.channel = channel
            controller.updater.resetUpdateCycle()
        }
    }

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var availableUpdateVersion: String?
    @Published private(set) var lastCheckDate: Date?

    var isUpdateAvailable: Bool { availableUpdateVersion != nil }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    private let controller: SPUStandardUpdaterController
    private let updaterDelegate: UpdaterDelegate

    override init() {
        let storedChannel =
            UserDefaults.standard.string(forKey: Keys.channel)
            .flatMap(Channel.init(rawValue:)) ?? .stable
        let delegate = UpdaterDelegate(channel: storedChannel)
        self.updaterDelegate = delegate
        self.channel = storedChannel
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        super.init()

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)

        lastCheckDate = controller.updater.lastUpdateCheckDate
        delegate.onCheckCompleted = { [weak self] date in
            Task { @MainActor in self?.lastCheckDate = date }
        }
        delegate.onFoundUpdate = { [weak self] version in
            Task { @MainActor in self?.availableUpdateVersion = version }
        }
        delegate.onUserChoice = { [weak self] keepsReminder in
            Task { @MainActor in
                if !keepsReminder { self?.availableUpdateVersion = nil }
            }
        }
        delegate.onNoPendingUpdate = { [weak self] in
            Task { @MainActor in self?.availableUpdateVersion = nil }
        }
    }

    func start() {
        #if DEBUG
        canCheckForUpdates = false
        #else
        controller.startUpdater()
        canCheckForUpdates = controller.updater.canCheckForUpdates
        #endif
    }

    func checkForUpdates() {
        #if DEBUG
        return
        #else
        controller.checkForUpdates(nil)
        #endif
    }

    private enum Keys {
        static let channel = "updates.channel"
    }
}

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var channel: UpdateService.Channel
    var onFoundUpdate: ((String) -> Void)?
    var onUserChoice: ((Bool) -> Void)?
    var onNoPendingUpdate: (() -> Void)?
    var onCheckCompleted: ((Date?) -> Void)?

    init(channel: UpdateService.Channel) {
        self.channel = channel
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        switch channel {
        case .stable: []
        case .beta: ["beta"]
        }
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        guard channel == .beta else { return nil }
        let bundleFeed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        return bundleFeed?.replacingOccurrences(
            of: "releases/latest/download",
            with: "releases/download/beta"
        ) ?? "https://github.com/jx-grxf/BottleLite/releases/download/beta/appcast.xml"
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        onFoundUpdate?(item.displayVersionString)
    }

    func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate updateItem: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        onUserChoice?(choice == .dismiss)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        onNoPendingUpdate?()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        onNoPendingUpdate?()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        onCheckCompleted?(updater.lastUpdateCheckDate)
    }
}
