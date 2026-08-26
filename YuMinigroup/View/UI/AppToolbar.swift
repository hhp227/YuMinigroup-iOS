import SwiftUI

enum NavigationIcon {
    case menu
    case back
}

struct AppToolbar: View {
    let title: String
    let navigationIcon: NavigationIcon
    let onNavigationClick: () -> Void
    var transparent = false

    var body: some View {
        HStack(spacing: 0) {
            if navigationIcon == .menu {
                Button(action: buttonAction) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .foregroundColorCompat(Color.white)
                }

                Text(title)
                    .font(.title3.weight(.medium))
                    .lineLimit(1)
                    .foregroundColorCompat(Color.white)
            } else {
                Color.clear
                    .frame(width: 56, height: 56)
            }

            Spacer()
        }
        .frame(height: 56)
        .background(transparent ? Color.clear : Color.accentColor)
    }

    private func buttonAction() {
        onNavigationClick()
    }
}
