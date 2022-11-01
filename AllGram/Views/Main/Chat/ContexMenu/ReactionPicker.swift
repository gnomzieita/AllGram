import SwiftUI

struct ReactionPicker: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    let emoji = ["👍", "👎", "😄", "😕", "🎉", "❤️", "🚀", "👀"]

    let picked: (String) -> Void

    var body: some View {
        VStack {
            Text(verbatim: L10n.ReactionPicker.title)
                .foregroundColor(.gray)
                .font(.headline)
                .padding(.bottom, 30)
            HStack(spacing: 10) {
                ForEach(emoji, id: \.self) { emoji in
                    Button(action: { self.picked(emoji) },
                           label: {
                        Text(emoji)
                            .font(.largeTitle)
                    })
                }
            }
            Button(action: {
                withAnimation { presentationMode.wrappedValue.dismiss()
                }
            }) {
                Text("Cancel")
                    .foregroundColor(.accentColor)
                    .font(.headline)
                    .padding(.top, 30)
            }
        }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker(picked: { _ in })
    }
}
