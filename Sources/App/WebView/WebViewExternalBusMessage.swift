import Foundation

enum WebViewExternalBusMessage: String, CaseIterable {
    case configGet = "config/get"
    case configScreenShow = "config_screen/show"
    case haptic
    case connectionStatus = "connection-status"
    case tagRead = "tag/read"
    case tagWrite = "tag/write"
    case themeUpdate = "theme-update"
    case matterCommission = "matter/commission"
    case threadImportCredentials = "thread/import_credentials"
    case threadStoreCredentialInAppleKeychain = "thread/store_in_platform_keychain"
    case barCodeScanner = "bar_code/scan"
    case barCodeScannerClose = "bar_code/close"
    case barCodeScannerNotify = "bar_code/notify"
    case assistShow = "assist/show"
    case scanForImprov = "improv/scan"
    case improvConfigureDevice = "improv/configure_device"
}

enum WebViewExternalBusOutgoingMessage: String, CaseIterable {
    case showSidebar = "sidebar/show"
    case showAutomationEditor = "automation/editor/show"
    case barCodeScanResult = "bar_code/scan_result"
    case barCodeScanAborted = "bar_code/aborted"
    case improvDiscoveredDevice = "improv/discovered_device"
    case improvDiscoveredDeviceSetupDone = "improv/device_setup_done"
    case navigate = "navigate"
}
