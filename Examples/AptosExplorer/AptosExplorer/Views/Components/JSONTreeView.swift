import SwiftUI
import AptosSDK

struct JSONTreeView: View {
    let value: Any
    let label: String?

    init(_ value: Any, label: String? = nil) {
        self.value = value
        self.label = label
    }

    var body: some View {
        renderValue(value, label: label)
    }

    private func renderValue(_ val: Any, label: String?) -> AnyView {
        if let dict = val as? [String: Any] {
            return AnyView(
                DisclosureGroup {
                    ForEach(dict.keys.sorted(), id: \.self) { key in
                        JSONTreeView(dict[key]!, label: key)
                    }
                } label: {
                    if let label {
                        Text(label)
                            .fontWeight(.medium)
                    } else {
                        Text("Object (\(dict.count) keys)")
                            .foregroundStyle(.secondary)
                    }
                }
            )
        } else if let array = val as? [Any] {
            return AnyView(
                DisclosureGroup {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, element in
                        JSONTreeView(element, label: "[\(index)]")
                    }
                } label: {
                    if let label {
                        Text(label)
                            .fontWeight(.medium)
                    } else {
                        Text("Array (\(array.count) items)")
                            .foregroundStyle(.secondary)
                    }
                }
            )
        } else if let codable = val as? AnyCodable {
            return renderValue(codable.value, label: label)
        } else {
            return AnyView(
                HStack {
                    if let label {
                        Text(label)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                    Text("\(String(describing: val))")
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            )
        }
    }
}
