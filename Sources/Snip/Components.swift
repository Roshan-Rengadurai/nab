import SwiftUI

// MARK: - Detail pane header (icon chip + title)

struct PaneHeader: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Gruv.bg0h)
                )
            Text(title)
                .font(.mono(17, weight: .semibold))
                .foregroundColor(Gruv.fg0)
            Spacer()
        }
    }
}

// MARK: - Card container

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Gruv.bg1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Gruv.bg2, lineWidth: 1)
            )
    }
}

// MARK: - Toggle row

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg1)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundColor(Gruv.gray)
                    }
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Gruv.orange)
            }
        }
    }
}

// MARK: - Text field row

struct FieldRow: View {
    let title: String
    var placeholder: String = ""
    var secure: Bool = false
    @Binding var text: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(Gruv.fg3)
                Group {
                    if secure { SecureField(placeholder, text: $text) }
                    else { TextField(placeholder, text: $text) }
                }
                .textFieldStyle(.plain)
                .font(.mono(12))
                .foregroundColor(Gruv.fg0)
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 7).fill(Gruv.bg0h))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Gruv.bg2, lineWidth: 1))
            }
        }
    }
}

// MARK: - Segmented card picker (the White / Accent / Decibel style)

struct CardOption: Identifiable, Equatable {
    let id: String
    let symbol: String
    let label: String
}

struct SegmentedCards: View {
    let options: [CardOption]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { opt in
                let selected = opt.id == selection
                Button {
                    selection = opt.id
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: opt.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selected ? Gruv.orange : Gruv.fg3)
                        Text(opt.label)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .foregroundColor(selected ? Gruv.fg0 : Gruv.fg3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? Gruv.orange.opacity(0.12) : Gruv.bg1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selected ? Gruv.orange : Gruv.bg2, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Slider row with value chip (the Duration style)

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(Gruv.fg1)
                    Spacer()
                    Text(valueLabel)
                        .font(.mono(11, weight: .medium))
                        .foregroundColor(Gruv.fg0)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Gruv.bg0h))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Gruv.bg2, lineWidth: 1))
                }
                Slider(value: $value, in: range, step: step)
                    .tint(Gruv.orange)
            }
        }
    }
}

// MARK: - Section label above a group of cards

struct GroupLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Gruv.gray)
            .padding(.leading, 2)
    }
}
