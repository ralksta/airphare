import AirPhareCore
import SwiftUI

struct SettingsInlineView: View {
    @Bindable var vm: MonitorViewModel
    let onClose: () -> Void

    private let intervals = [1, 3, 5, 10, 15, 30]
    private let preferredChannels = [0, 36, 52, 100, 116]

    private var lang: ResolvedLanguage { vm.lang }
    private func t(_ key: L10nKey) -> String { L10n.t(key, lang: lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Section(t(.settingsSectionMonitoring)) {
                    Picker(t(.settingsLanguage), selection: $vm.settings.language) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Picker(t(.settingsInterval), selection: $vm.settings.checkIntervalMinutes) {
                        ForEach(intervals, id: \.self) { min in
                            Text(L10n.fmt(.settingsEveryMinutes, lang: lang, min)).tag(min)
                        }
                    }

                    Picker(t(.settingsPreferredChannel), selection: $vm.settings.preferred5GHzChannel) {
                        ForEach(preferredChannels, id: \.self) { ch in
                            Text(ch == 0 ? t(.settingsChannelAny) : L10n.fmt(.settingsChannelN, lang: lang, ch)).tag(ch)
                        }
                    }

                    Toggle(t(.settingsWarn2GHz), isOn: $vm.settings.expect5GHz)
                    Toggle(t(.settingsNotifications), isOn: $vm.settings.notificationsEnabled)
                    Toggle(t(.settingsShowMenuBarMetrics), isOn: $vm.settings.showMenuBarMetrics)
                }

                Section(t(.settingsSectionThresholds)) {
                    Stepper(L10n.fmt(.settingsSNRThreshold, lang: lang, vm.settings.snrWarningThreshold),
                            value: $vm.settings.snrWarningThreshold, in: 12...35)
                    Stepper(L10n.fmt(.settingsGatewayThreshold, lang: lang, Int(vm.settings.gatewayAvgWarningMs)),
                            value: $vm.settings.gatewayAvgWarningMs, in: 10...80, step: 5)
                    Stepper(L10n.fmt(.settingsDNSThreshold, lang: lang, vm.settings.dnsWarningMs),
                            value: $vm.settings.dnsWarningMs, in: 40...250, step: 10)

                    TextField(t(.settingsRouterURL), text: $vm.settings.routerURL)
                        .textFieldStyle(.roundedBorder)
                }

                Section(t(.settingsSectionSystem)) {
                    Toggle(t(.settingsLaunchAtLogin), isOn: Binding(
                        get: { vm.launchAtLoginEnabled },
                        set: { vm.setLaunchAtLogin($0) }
                    ))
                    .disabled(Bundle.main.bundleURL.pathExtension != "app")

                    Button(t(.settingsRequestLocation)) {
                        vm.notifications.requestLocationForSSID()
                    }
                    .controlSize(.small)
                }
            }
            .formStyle(.grouped)
            .frame(height: 415)

            HStack {
                Button(t(.settingsDefaults)) {
                    vm.settings = .default
                }
                .controlSize(.small)

                Spacer()

                Button(t(.settingsDone)) {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
