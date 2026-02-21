import SwiftUI

struct BadgeLabelView: View {
    let count: Int
    var size: CGFloat = 22

    private var fontSize: CGFloat {
        size * 0.56
    }

    var body: some View {
        Text("\(count)")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.3)
            .frame(minWidth: size, minHeight: size)
            .frame(height: size)
            .background(
                Capsule()
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
            )
            .fixedSize()
    }
}
