
import SwiftUI
import CoreBluetooth

struct AccountView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var bluetoothManager: BluetoothManager

    @State private var showTrainingDays = false
    @State private var showSetsPicker = false
    @State private var showRepsPicker = false
    @State private var showHoldDurationPicker = false
    @State private var showDeviceSheet = false
    @State private var showSavedMessage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                personalInformationCard
                trainingPlanCard
                deviceManagementCard
                saveButton
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSetsPicker) { setsPickerSheet }
        .sheet(isPresented: $showRepsPicker) { repsPickerSheet }
        .sheet(isPresented: $showHoldDurationPicker) { holdDurationSheet }
        .sheet(isPresented: $showDeviceSheet, onDismiss: { bluetoothManager.stopScan() }) {
            DevicePickerSheet()
                .environmentObject(bluetoothManager)
        }
        .alert("Settings Saved", isPresented: $showSavedMessage) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Sections
private extension AccountView {
    var personalInformationCard: some View {
        settingsCard(title: "Personal Information") {
            editableRow(title: "Name", text: $settings.name, placeholder: "Enter your name")
            editableRow(title: "Email", text: $settings.email, placeholder: "Enter your email", keyboard: .emailAddress)
            editableRow(title: "Age", text: $settings.age, placeholder: "Enter your age", keyboard: .numberPad)
        }
    }

    var trainingPlanCard: some View {
        settingsCard(title: "Training Plan") {
            VStack(spacing: 0) {
                trainingDaysRow
                Divider().padding(.vertical, 8)
                trainingModeRow
                if settings.trainingMode == .staticHold {
                    Divider().padding(.vertical, 8)
                    holdDurationRow
                }
                Divider().padding(.vertical, 8)
                setsPerDayRow
                Divider().padding(.vertical, 8)
                repsPerSetRow
            }
        }
    }

    var deviceManagementCard: some View {
        settingsCard(title: "Device Management") {
            VStack(spacing: 12) {
                HStack {
                    Text("Bluetooth Status")
                        .foregroundColor(.primaryText)
                    Spacer()
                    Text(bluetoothManager.bluetoothStateText)
                        .foregroundColor(bluetoothManager.isConnected ? .brandBlue : .secondaryText)
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                Button {
                    bluetoothManager.startScan()
                    showDeviceSheet = true
                } label: {
                    rowContainer {
                        Text("Bluetooth Device")
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text(bluetoothManager.connectedDeviceName ?? "Not Connected")
                            .foregroundColor(bluetoothManager.isConnected ? .brandBlue : .secondaryText)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                    .background(bluetoothManager.isConnected ? Color.neutralBlueBg : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(bluetoothManager.isConnected ? Color.brandBlue.opacity(0.20) : Color.clear, lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                if bluetoothManager.isConnected {
                    Divider()

                    Button {
                        bluetoothManager.disconnectCurrentDevice()
                    } label: {
                        Text("Disconnect Device")
                            .foregroundColor(.warningAmber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var saveButton: some View {
        Button {
            showSavedMessage = true
        } label: {
            Text("Save")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandBlue)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }
}

// MARK: - Training Plan Rows
private extension AccountView {
    var trainingDaysRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    showTrainingDays.toggle()
                }
            } label: {
                rowContainer {
                    Text("Training Days")
                        .foregroundColor(.primaryText)
                    Spacer()
                    Text(settings.trainingDaysText)
                        .foregroundColor(.secondaryText)
                    Image(systemName: showTrainingDays ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if showTrainingDays {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    ForEach(Weekday.allCases) { day in
                        let isSelected = settings.trainingDays.contains(day)

                        Button {
                            if isSelected {
                                if settings.trainingDays.count > 1 {
                                    settings.trainingDays.remove(day)
                                }
                            } else {
                                settings.trainingDays.insert(day)
                            }
                        } label: {
                            Text(day.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(isSelected ? .white : .primaryText)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? Color.brandBlue : Color.appBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.brandBlue : Color.lineSoft, lineWidth: 1)
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
        }
    }

    var trainingModeRow: some View {
        rowContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Training Mode")
                    .foregroundColor(.primaryText)

                Picker("", selection: $settings.trainingMode) {
                    ForEach(TrainingMode.allCases) { mode in
                        Text(mode.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .onChange(of: settings.trainingMode) { _ in
                    settings.ensureValidReps()
                }
            }
            .padding(.vertical, 4)
        }
    }

    var holdDurationRow: some View {
        Button {
            showHoldDurationPicker = true
        } label: {
            rowContainer {
                Text("Hold Duration")
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(settings.staticHoldDurationSec)s")
                    .foregroundColor(.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    var setsPerDayRow: some View {
        Button {
            showSetsPicker = true
        } label: {
            rowContainer {
                Text("Sets Per Day")
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(settings.setsPerDay)")
                    .foregroundColor(.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    var repsPerSetRow: some View {
        Button {
            showRepsPicker = true
        } label: {
            rowContainer {
                Text("Repetitions Per Set")
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(settings.repsPerSet)")
                    .foregroundColor(.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheets
private extension AccountView {
    var setsPickerSheet: some View {
        NumberPickerSheet(
            title: "Sets Per Day",
            options: Array(1...5),
            selection: $settings.setsPerDay
        )
    }

    var repsPickerSheet: some View {
        NumberPickerSheet(
            title: "Repetitions Per Set",
            options: settings.repOptions,
            selection: $settings.repsPerSet
        )
    }

    var holdDurationSheet: some View {
        NumberPickerSheet(
            title: "Hold Duration",
            options: [5, 10, 15, 20],
            selection: $settings.staticHoldDurationSec,
            suffix: "s"
        )
    }
}

// MARK: - Helpers
private extension AccountView {
    @ViewBuilder
    func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primaryText)
            Divider()
            content()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    func rowContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            content()
        }
        .frame(minHeight: 32)
    }

    @ViewBuilder
    func editableRow(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primaryText)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondaryText)
                .textInputAutocapitalization(.never)
        }
    }
}

// MARK: - Number Picker Sheet
struct NumberPickerSheet: View {
    let title: String
    let options: [Int]
    @Binding var selection: Int
    var suffix: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { value in
                        Text("\(value)\(suffix)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(260)])
    }
}

// MARK: - Device Picker Sheet
struct DevicePickerSheet: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if bluetoothManager.discoveredDevices.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 28))
                            .foregroundColor(.infoBlueSoft)
                        Text("No devices found yet")
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                                deviceRow(device)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Select Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Rescan") {
                        bluetoothManager.startScan()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func deviceRow(_ device: CBPeripheral) -> some View {
        let name = device.name ?? "Unknown Device"
        let isTarget = name == "ForceMeter"

        return Button {
            bluetoothManager.connect(device)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                            .foregroundColor(.primaryText)

                        if isTarget {
                            StatusBadge(text: "Target", style: .neutral)
                        }
                    }

                    Text(device.identifier.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "bolt.horizontal.circle")
                    .foregroundColor(isTarget ? .brandBlue : .infoBlueSoft)
            }
            .padding()
            .background(isTarget ? Color.neutralBlueBg : Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isTarget ? Color.brandBlue.opacity(0.18) : Color.lineSoft.opacity(0.6), lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AccountView()
            .environmentObject(AppSettings())
            .environmentObject(BluetoothManager())
    }
}
