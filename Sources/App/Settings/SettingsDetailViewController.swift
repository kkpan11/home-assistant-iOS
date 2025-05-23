import CoreMotion
import Eureka
import FirebaseMessaging
import Intents
import IntentsUI
import PromiseKit
import RealmSwift
import Shared
import UIKit
import Version

enum SettingsDetailsGroup: String {
    case display
    case actions
    case location
}

class SettingsDetailViewController: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: SettingsDetailsGroup = .display

    var doneButton: Bool = false

    private let realm = Current.realm()
    private var notificationTokens: [NotificationToken] = []
    private var notificationCenterTokens: [AnyObject] = []
    private var reorderingRows: [String: BaseRow] = [:]

    deinit {
        notificationCenterTokens.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if doneButton {
            navigationItem.rightBarButtonItem = nil
            doneButton = false
        }
        onDismissCallback?(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if doneButton {
            let closeSelector = #selector(SettingsDetailViewController.closeSettingsDetailView(_:))
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: closeSelector
            )
            navigationItem.setRightBarButton(doneButton, animated: true)
        }

        switch detailGroup {
        case .location:
            title = L10n.SettingsDetails.Location.title
            form
                +++ locationPermissionsSection()

                +++ ButtonRow {
                    $0.title = L10n.Settings.LocationHistory.title
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        LocationHistoryListViewHostingController(rootView: LocationHistoryListView())
                    }), onDismiss: nil)
                }

                <<< ButtonRowWithLoading {
                    $0.title = L10n.SettingsDetails.Location.updateLocation
                    $0.onCellSelection { [weak self] _, row in
                        row.value = true
                        row.updateCell()

                        firstly {
                            HomeAssistantAPI.manuallyUpdate(
                                applicationState: UIApplication.shared.applicationState,
                                type: .userRequested
                            )
                        }.ensure {
                            row.value = false
                            row.updateCell()
                        }.catch { error in
                            let alert = UIAlertController(
                                title: nil,
                                message: error.localizedDescription,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
                            self?.present(alert, animated: true, completion: nil)
                        }
                    }
                }

                +++ Section(
                    header: L10n.SettingsDetails.Location.Updates.header,
                    footer: L10n.SettingsDetails.Location.Updates.footer
                )
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Zone.title
                    $0.value = Current.settingsStore.locationSources.zone
                    $0.disabled = .location(conditions: [.permissionNotAlways, .accuracyNotFull])
                }.onChange({ row in
                    Current.settingsStore.locationSources.zone = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Background.title
                    $0.value = Current.settingsStore.locationSources.backgroundFetch
                    $0.disabled = .location(conditions: [
                        .permissionNotAlways,
                        .backgroundRefreshNotAvailable,
                    ])
                    $0.hidden = .isCatalyst
                }.onChange({ row in
                    Current.settingsStore.locationSources.backgroundFetch = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Significant.title
                    $0.value = Current.settingsStore.locationSources.significantLocationChange
                    $0.disabled = .location(conditions: [.permissionNotAlways])
                }.onChange({ row in
                    Current.settingsStore.locationSources.significantLocationChange = row.value ?? true
                })
                <<< SwitchRow {
                    $0.title = L10n.SettingsDetails.Location.Updates.Notification.title
                    $0.value = Current.settingsStore.locationSources.pushNotifications
                    $0.disabled = .location(conditions: [.permissionNotAlways])
                }.onChange({ row in
                    Current.settingsStore.locationSources.pushNotifications = row.value ?? true
                })

            let zoneEntities = realm.objects(RLMZone.self)
            for zone in zoneEntities {
                form
                    +++ Section(header: zone.Name, footer: "") {
                        $0.tag = zone.identifier
                    }
                    <<< SwitchRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.EnterExitTracked.title
                        $0.value = zone.TrackingEnabled
                        $0.disabled = Condition(booleanLiteral: true)
                    }
                    <<< LocationRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.Location.title
                        $0.value = zone.location
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.Radius.title
                        $0.value = L10n.SettingsDetails.Location.Zones.Radius.label(Int(zone.Radius))
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconUuid.title
                        $0.value = zone.BeaconUUID
                        $0.hidden = Condition(booleanLiteral: zone.BeaconUUID == nil)
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMajor.title
                        if let major = zone.BeaconMajor.value {
                            $0.value = String(describing: major)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: zone.BeaconMajor.value == nil)
                    }
                    <<< LabelRow {
                        $0.title = L10n.SettingsDetails.Location.Zones.BeaconMinor.title
                        if let minor = zone.BeaconMinor.value {
                            $0.value = String(describing: minor)
                        } else {
                            $0.value = L10n.SettingsDetails.Location.Zones.Beacon.PropNotSet.value
                        }
                        $0.hidden = Condition(booleanLiteral: zone.BeaconMinor.value == nil)
                    }
            }
            if zoneEntities.count > 0 {
                form +++ InfoLabelRow {
                    $0.title = L10n.SettingsDetails.Location.Zones.footer
                }
            }

        case .actions:
            title = L10n.SettingsDetails.LegacyActions.title
            let actions = realm.objects(Action.self)
                .sorted(byKeyPath: "Position")
                .filter("Scene == nil")

            let actionsFooter = Current.isCatalyst ?
                L10n.SettingsDetails.Actions.footerMac : L10n.SettingsDetails.Actions.footer

            let learnAboutActionsButton = SettingsButtonRow {
                $0.title = L10n.SettingsDetails.Actions.Learn.Button.title
                $0.accessoryIcon = .openInNewIcon
                $0.onCellSelection { _, row in
                    guard let url = URL(string: "https://companion.home-assistant.io/docs/core/actions/") else { return }
                    UIApplication.shared.open(url)
                    row.deselect(animated: true)
                }
            }
            form +++ learnAboutActionsButton
            form +++ MultivaluedSection(
                multivaluedOptions: [.Insert, .Delete, .Reorder],
                header: "",
                footer: actionsFooter
            ) { section in
                section.tag = "actions"
                section.multivaluedRowToInsertAt = { [weak self] _ -> ButtonRowWithPresent<ActionConfigurator> in
                    self?.getActionRow(nil) ?? .init()
                }
                section.addButtonProvider = { _ in
                    ButtonRow {
                        $0.title = L10n.addButtonLabel
                        $0.cellStyle = .value1
                        $0.tag = "add_action"
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                }

                for action in actions.filter("isServerControlled == false") {
                    section <<< getActionRow(action)
                }
            }

            form +++ RealmSection(
                header: L10n.SettingsDetails.Actions.ActionsSynced.header,
                footer: nil,
                collection: AnyRealmCollection(actions.filter("isServerControlled == true")),
                emptyRows: [
                    LabelRow {
                        $0.title = L10n.SettingsDetails.Actions.ActionsSynced.empty
                        $0.disabled = true
                    },
                ], getter: { [weak self] in self?.getActionRow($0) },
                didUpdate: { section, collection in
                    if collection.isEmpty {
                        section.footer = HeaderFooterView(
                            title: L10n.SettingsDetails.Actions.ActionsSynced.footerNoActions
                        )
                    } else {
                        section.footer = HeaderFooterView(
                            title: L10n.SettingsDetails.Actions.ActionsSynced.footer
                        )
                    }
                }
            )

            form +++ ButtonRow {
                $0.title = L10n.SettingsDetails.Actions.ServerControlled.Update.title
                $0.onCellSelection { _, _ in
                    let result = Current.modelManager.fetch()
                    result.pipe { result in
                        switch result {
                        case .fulfilled:
                            break
                        case let .rejected(error):
                            Current.Log.error("Failed to manually update server Actions: \(error.localizedDescription)")
                        }
                    }
                }
            }

            let scenes = realm.objects(RLMScene.self).sorted(byKeyPath: RLMScene.positionKeyPath)

            let toggleAllSwitch = SwitchRow()
            with(toggleAllSwitch) {
                $0.title = L10n.SettingsDetails.Actions.Scenes.selectAll
                $0.onChange { [weak self] row in
                    guard let self,
                          let value = row.value else { return }
                    realm.reentrantWrite {
                        for scene in scenes {
                            scene.actionEnabled = value
                        }
                    }
                }
            }

            var scenesUpdateObserver: NotificationToken?
            toggleAllSwitch.cellUpdate { cell, _ in
                scenesUpdateObserver = scenes.observe { _ in
                    cell.switchControl.setOn(scenes.filter(\.actionEnabled).count == scenes.count, animated: true)
                }
            }
            toggleAllSwitch.updateCell()

            form +++ Section(L10n.SettingsDetails.Actions.Scenes.title)
                <<< toggleAllSwitch
            form +++ RealmSection<RLMScene>(
                footer: L10n.SettingsDetails.Actions.Scenes.footer,
                collection: AnyRealmCollection(scenes),
                emptyRows: [
                    LabelRow {
                        $0.title = L10n.SettingsDetails.Actions.Scenes.empty
                        $0.disabled = true
                    },
                ], getter: {
                    Self.getSceneRows($0)
                }
            )
        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // Log in case user is running with internal URL set but not configured local access
        for server in Current.servers.all {
            if server.info.connection.hasInternalURLSet,
               server.info.connection.internalSSIDs?.isEmpty ?? true,
               server.info.connection.internalHardwareAddresses?.isEmpty ?? true {
                let message =
                    "Server \(server.info.name) - Internal URL set but no internal SSIDs or hardware addresses set"
                Current.Log.error(message)
                Current.clientEventStore.addEvent(.init(text: message, type: .settings))
            }
        }
    }

    override func tableView(_ tableView: UITableView, willBeginReorderingRowAtIndexPath indexPath: IndexPath) {
        let row = form[indexPath]
        guard let rowTag = row.tag else { return }
        reorderingRows[rowTag] = row

        super.tableView(tableView, willBeginReorderingRowAtIndexPath: indexPath)
    }

    private func updatePositions() {
        guard let actionsSection = form.sectionBy(tag: "actions") as? MultivaluedSection else {
            return
        }

        let rowsDict = actionsSection.allRows.enumerated().compactMap { entry -> (String, Int)? in
            // Current.Log.verbose("Map \(entry.element.indexPath) \(entry.element.tag)")
            guard let tag = entry.element.tag else { return nil }

            return (tag, entry.offset)
        }

        let rowPositions = Dictionary(uniqueKeysWithValues: rowsDict)

        realm.beginWrite()

        for storedAction in realm.objects(Action.self).sorted(byKeyPath: "Position") {
            guard let newPos = rowPositions[storedAction.ID] else { continue }
            storedAction.Position = Action.PositionOffset.manual.rawValue + newPos
            // Current.Log.verbose("Update action \(storedAction.ID) to pos \(newPos)")
        }

        try? realm.commitWrite()
    }

    @objc public func tableView(_ tableView: UITableView, didEndReorderingRowAtIndexPath indexPath: IndexPath) {
        let row = form[indexPath]
        Current.Log.verbose("Setting action \(row) to position \(indexPath.row)")

        updatePositions()

        reorderingRows[row.tag ?? ""] = nil
    }

    @objc func tableView(_ tableView: UITableView, didCancelReorderingRowAtIndexPath indexPath: IndexPath) {
        guard let rowTag = form[indexPath].tag else { return }
        reorderingRows[rowTag] = nil
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)

        let deletedIDs = rows.filter {
            guard let tag = $0.tag else { return false }
            return reorderingRows[tag] == nil
        }.compactMap(\.tag)

        if deletedIDs.count == 0 { return }

        Current.Log.verbose("Rows removed \(rows), \(deletedIDs)")

        let realm = Realm.live()

        if (rows.first as? ButtonRowWithPresent<ActionConfigurator>) != nil {
            Current.Log.verbose("Removed row is ActionConfiguration \(deletedIDs)")
            realm.reentrantWrite {
                realm.delete(realm.objects(Action.self).filter("ID IN %@", deletedIDs))
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    private func resizeImage(image: UIImage?, newSize: CGSize) -> UIImage? {
        guard let image else { return nil }
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage
    }

    static func getSceneRows(_ rlmScene: RLMScene) -> [BaseRow] {
        let switchRow = SwitchRow()
        let configure = ButtonRowWithPresent<ActionConfigurator> {
            $0.title = L10n.SettingsDetails.Actions.Scenes.customizeAction
            $0.disabled = .function([], { _ in switchRow.value == false })
            $0.cellUpdate { cell, row in
                cell.separatorInset = .zero
                cell.textLabel?.textAlignment = .natural
                cell.imageView?.image = UIImage(size: MaterialDesignIcons.settingsIconSize, color: .clear)
                cell.textLabel?.textColor = row.isDisabled == false ? AppConstants.tintColor : .tertiaryLabel
            }

            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ActionConfigurator(action: rlmScene.actions.first!)
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? ActionConfigurator, vc.shouldSave, let realm = rlmScene.realm {
                    realm.reentrantWrite {
                        realm.add(vc.action, update: .all)
                    }
                }
            })
        }

        _ = with(switchRow) {
            $0.title = rlmScene.name ?? rlmScene.identifier
            $0.value = rlmScene.actionEnabled
            $0.cellUpdate { cell, _ in
                cell.imageView?.image =
                    rlmScene.icon
                        .flatMap({ MaterialDesignIcons(serversideValueNamed: $0) })?
                        .settingsIcon(for: cell.traitCollection)
            }
            $0.onChange { row in
                do {
                    try rlmScene.realm?.write {
                        rlmScene.actionEnabled = row.value ?? true
                    }

                    configure.evaluateDisabled()
                } catch {
                    Current.Log.error("couldn't write action update: \(error)")
                }
            }
        }

        return [switchRow, configure]
    }

    func getActionRow(_ inputAction: Action?) -> ButtonRowWithPresent<ActionConfigurator> {
        var identifier = UUID().uuidString
        var title = L10n.ActionsConfigurator.title
        var action = inputAction

        if let passedAction = inputAction {
            identifier = passedAction.ID
            title = passedAction.Name
        }

        return ButtonRowWithPresent<ActionConfigurator> {
            $0.tag = identifier
            $0.title = title
            $0.cellStyle = .subtitle
            $0.displayValueFor = { _ in
                guard action == nil || action?.isInvalidated == false else { return nil }
                return action?.Text ?? L10n.ActionsConfigurator.Rows.Text.title
            }
            $0.cellSetup { cell, _ in
                cell.detailTextLabel?.textColor = .secondaryLabel
            }
            $0.cellUpdate { cell, _ in
                guard action == nil || action?.isInvalidated == false else { return }
                cell.imageView?.image = MaterialDesignIcons(named: action?.IconName ?? "")
                    .settingsIcon(for: cell.traitCollection)
            }
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ActionConfigurator(action: action)
            }, onDismiss: { [weak self] vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? ActionConfigurator {
                    defer {
                        if vc.shouldOpenAutomationEditor {
                            vc.navigationController?.dismiss(animated: true, completion: {
                                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                                    .done { controller in
                                        controller.openActionAutomationEditor(actionId: vc.action.ID)
                                    }
                            })
                        }
                    }

                    if vc.shouldSave == false {
                        Current.Log.verbose("Not saving action to DB and returning early!")
                        return
                    }

                    action = vc.action
                    vc.row.tag = vc.action.ID
                    vc.row.title = vc.action.Name
                    vc.row.updateCell()

                    Current.Log.verbose("Saving action! \(vc.action)")

                    let realm = Current.realm()
                    realm.reentrantWrite {
                        realm.add(vc.action, update: .all)
                    }.done {
                        self?.updatePositions()
                    }.cauterize()
                }
            })
        }
    }

    private func locationPermissionsSection() -> Section {
        let section = Section()

        section <<< locationPermissionRow()
        section <<< locationAccuracyRow()
        section <<< backgroundRefreshRow()

        return section
    }

    private func locationPermissionRow() -> BaseRow {
        class PermissionWatchingDelegate: NSObject, CLLocationManagerDelegate {
            let row: LocationPermissionRow

            init(row: LocationPermissionRow) {
                self.row = row
            }

            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                row.value = manager.authorizationStatus
                row.updateCell()
            }

            func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
                row.value = status
                row.updateCell()
            }
        }

        return LocationPermissionRow("locationPermission") {
            let locationManager = CLLocationManager()
            let permissionDelegate = PermissionWatchingDelegate(row: $0)

            $0.title = L10n.SettingsDetails.Location.LocationPermission.title

            $0.cellUpdate { cell, _ in
                // setting the delegate also has the side effect of triggering a status update, which sets the value
                locationManager.delegate = permissionDelegate

                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            $0.onCellSelection { _, row in
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestAlwaysAuthorization()
                } else {
                    UIApplication.shared.openSettings(destination: .location)
                }

                row.deselect(animated: true)
            }
        }
    }

    private func locationAccuracyRow() -> BaseRow {
        class PermissionWatchingDelegate: NSObject, CLLocationManagerDelegate {
            let row: LocationAccuracyRow

            init(row: LocationAccuracyRow) {
                self.row = row
            }

            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                row.value = manager.accuracyAuthorization
                row.updateCell()
            }
        }

        return LocationAccuracyRow("locationAccuracy") {
            let locationManager = CLLocationManager()
            let permissionDelegate = PermissionWatchingDelegate(row: $0)

            $0.title = L10n.SettingsDetails.Location.LocationAccuracy.title

            $0.cellUpdate { cell, _ in
                // setting the delegate also has the side effect of triggering a status update, which sets the value
                locationManager.delegate = permissionDelegate

                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            $0.onCellSelection { _, row in
                UIApplication.shared.openSettings(destination: .location)
                row.deselect(animated: true)
            }
        }
    }

    private func backgroundRefreshRow() -> BaseRow {
        BackgroundRefreshStatusRow("backgroundRefresh") { row in
            func updateRow(isInitial: Bool) {
                row.value = UIApplication.shared.backgroundRefreshStatus

                if !isInitial {
                    row.updateCell()
                }
            }

            notificationCenterTokens.append(NotificationCenter.default.addObserver(
                forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateRow(isInitial: false)
            })

            updateRow(isInitial: true)

            row.hidden = .isCatalyst
            row.title = L10n.SettingsDetails.Location.BackgroundRefresh.title
            row.cellUpdate { cell, _ in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            row.onCellSelection { _, row in
                UIApplication.shared.openSettings(destination: .backgroundRefresh)
                row.deselect(animated: true)
            }
        }
    }
}

enum OpenInBrowser: String, CaseIterable {
    case Chrome
    case Firefox
    case FirefoxFocus
    case FirefoxKlar
    case Safari
    case SafariInApp

    var title: String {
        switch self {
        case .Chrome:
            return L10n.SettingsDetails.General.OpenInBrowser.chrome
        case .Firefox:
            return L10n.SettingsDetails.General.OpenInBrowser.firefox
        case .FirefoxFocus:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxFocus
        case .FirefoxKlar:
            return L10n.SettingsDetails.General.OpenInBrowser.firefoxKlar
        case .Safari:
            return L10n.SettingsDetails.General.OpenInBrowser.default
        case .SafariInApp:
            return L10n.SettingsDetails.General.OpenInBrowser.safariInApp
        }
    }

    var isInstalled: Bool {
        switch self {
        case .Chrome:
            return OpenInChromeController.sharedInstance.isChromeInstalled()
        case .Firefox:
            return OpenInFirefoxControllerSwift().isFirefoxInstalled()
        case .FirefoxFocus:
            return OpenInFirefoxControllerSwift(type: .focus).isFirefoxInstalled()
        case .FirefoxKlar:
            return OpenInFirefoxControllerSwift(type: .klar).isFirefoxInstalled()
        default:
            return true
        }
    }

    var supportsPrivateTabs: Bool {
        switch self {
        case .Firefox:
            return true
        default:
            return false
        }
    }
}
