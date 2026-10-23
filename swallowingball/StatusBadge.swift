import SwiftUI

struct StatusBadge: View {
    let text: String
    let style: BadgeStyle

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.backgroundColor)
            .overlay(
                Capsule()
                    .stroke(style.borderColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}
