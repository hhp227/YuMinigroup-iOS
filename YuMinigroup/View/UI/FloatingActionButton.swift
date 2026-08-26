import SwiftUI

// Task 2에서는 예제 키트를 그대로 옮기며 action을 하드코딩된 no-op으로 남겨뒀다(제네릭화는 이 버튼을
// 처음 실제로 쓰는 Task 11 몫으로 미룸). 여기서 action을 주입 가능하게 바꾸되 시각 스타일은 그대로 둔다.
struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColorCompat(Color.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 6)
        }
    }
}
