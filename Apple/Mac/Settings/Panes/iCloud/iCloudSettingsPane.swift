import SwiftUI

struct iCloudSettingsPane: View {

    var body: some View {
        SettingsForm {
            iCloudSyncSettingsRows()
            SettingsGroupSpacer()
            iCloudBackupSettingsRows()
        }
    }
}
