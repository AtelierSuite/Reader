import SwiftUI

struct SheetDismissAction {

    let handler: @MainActor () -> Void

    @MainActor
    func callAsFunction() {
        handler()
    }
}

struct HostedSheetDismissAction {

    let handler: @MainActor () -> Bool
}

extension EnvironmentValues {
    // SwiftUI's dismiss does nothing in hosting controllers that AppKit presents as sheets.
    @Entry var hostedSheetDismissAction: HostedSheetDismissAction?
}

@propertyWrapper
struct SheetDismiss: DynamicProperty {

    @Environment(\.dismiss) private var swiftUIDismiss
    @Environment(\.hostedSheetDismissAction) private var hostedSheetDismissAction

    @MainActor
    var wrappedValue: SheetDismissAction {
        let swiftUIDismiss = swiftUIDismiss
        // isPresented is true inside AppKit-presented sheets too, so it can't tell them apart.
        guard let hostedSheetDismissAction else {
            return SheetDismissAction { swiftUIDismiss() }
        }
        return SheetDismissAction {
            if !hostedSheetDismissAction.handler() {
                swiftUIDismiss()
            }
        }
    }
}
