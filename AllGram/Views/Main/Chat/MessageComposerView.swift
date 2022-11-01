import SwiftUI

struct ExDivider: View {
    private let color: Color = .accentColor
    private let width: CGFloat = 3
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}

class AudioDurationCounter: ObservableObject {
    @Published var duration = 0
    
    private var dateStart: Date?
    
    private var stopCounting = false
    
    func startCount() {
        stop()
        dateStart = Date()
        var runner: (() -> ())?
        runner = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let dateStart = self?.dateStart else {
                    self?.stopCounting = true
                    return
                }
                self?.duration = Int(Date().timeIntervalSince(dateStart))
                runner?()
            }
        }
        runner?()
    }
    
    func stop(){
        self.stopCounting = true
        self.dateStart = nil
        self.duration = 0
    }
}

struct MessageComposerView: View, Equatable {
    static func == (lhs: MessageComposerView, rhs: MessageComposerView) -> Bool {
        return lhs.highlightMessage == rhs.highlightMessage
        && lhs.isEditing == rhs.isEditing
    }
    
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.sizeCategory) private var sizeCategory

    @ObservedObject private var durationCounter = AudioDurationCounter()
    
    @Binding var showAttachmentPicker: Bool

    @Binding var isEditing: Bool
    
    @State var isAudioRecorded = false
    @State var isRecordingLocked = false
    @State private var contentSizeThatFits: CGSize = .zero

    @Binding var attributedMessage: NSAttributedString

    var highlightMessage: String?
    let isHighlightForReply: Bool
    let disableSendIfNoInput: Bool

    let onCancel: () -> Void
    let onEditingChanged: (Bool) -> Void
    let onRecord: () -> Void
    let onRecordEnded: () -> Void
    let onRecordCancel: () -> Void
    let onCommit: () -> Void
    
    init(
        showAttachmentPicker: Binding<Bool>,
        isEditing: Binding<Bool>,
        attributedMessage: Binding<NSAttributedString>,
        highlightMessage: String? = nil,
        isHighlightForReply: Bool = false,
        disableSendIfNoInput: Bool = true,
        onCancel: @escaping () -> Void,
        onEditingChanged: @escaping (Bool) -> Void,
        onRecord: @escaping () -> Void,
        onRecordEnded: @escaping () -> Void,
        onRecordCancel: @escaping () -> Void,
        onCommit: @escaping () -> Void
    ) {
        self._showAttachmentPicker = showAttachmentPicker
        self._isEditing = isEditing
        self._attributedMessage = attributedMessage
        self.highlightMessage = highlightMessage
        self.isHighlightForReply = isHighlightForReply
        self.disableSendIfNoInput = disableSendIfNoInput
        self.onCancel = onCancel
        self.onEditingChanged = onEditingChanged
        self.onRecord = onRecord
        self.onRecordEnded = onRecordEnded
        self.onRecordCancel = onRecordCancel
        self.onCommit = onCommit
    }
    
    
    private let iconSize: CGFloat = 30

    private var backgroundColor: Color {
        colorScheme == .light ? Color(#colorLiteral(red: 0.9332506061, green: 0.937307477, blue: 0.9410644174, alpha: 1)) : Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))
    }

    private var gradient: LinearGradient {
        let color: Color = backgroundColor
        let colors: [Color]
        if colorScheme == .dark {
            colors = [color.opacity(1.0), color.opacity(0.85)]
        } else {
            colors = [color.opacity(0.85), color.opacity(1.0)]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10.0 * sizeCategory.scalingFactor)
            .fill(gradient).opacity(0.9)
    }

    @ViewBuilder private var highlightMessageView: some View {
        Divider()
        HStack {
            ExDivider()
                .background(Color.accentColor)
            VStack {
                HStack {
                    Text(verbatim: isHighlightForReply ? "Reply to:" : "Edit message:")
                        .frame(alignment: .leading)
                        .padding(.leading, 10)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Button(action: self.onCancel) {
                        SFSymbol.close
                            .font(.system(size: 20))
                            .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.cancelEdit))
                    }
                }
                Text(highlightMessage!)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: Alignment.leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    public var messageEditorHeight: CGFloat {
        return 35  //min(
//            self.contentSizeThatFits.height,
//            0.25 * UIScreen.main.bounds.height
//        )
    }

    private var attachmentPickerButton: some View {
        Button(action: {
            self.showAttachmentPicker.toggle()
        }, label: {
            Image("paperclip-solid")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.sendFile))
        })
    }

    private var messageEditorView: some View {
        let textAttributes = TextAttributes(autocapitalizationType: .sentences)
        return MultilineTextField(
            attributedText: $attributedMessage,
            placeholder: L10n.Composer.newMessage,
            isEditing: self.$isEditing,
            textAttributes: textAttributes,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
        .background(self.background)
        .onPreferenceChange(ContentSizeThatFitsKey.self) {
            self.contentSizeThatFits = $0
        }
        .frame(height: self.messageEditorHeight)
    }
    
    private var audioInfoView: some View {
        HStack{
            Circle()
                .fill(Color.red)
                .aspectRatio(1, contentMode: .fit)
                .padding()
            Text("\(String(format: "%02d", Int(durationCounter.duration / 60))):\(String(format: "%02d", durationCounter.duration - 60 * Int(durationCounter.duration / 60)))")
            Spacer()
        }
        .background(self.background)
        .onPreferenceChange(ContentSizeThatFitsKey.self) {
            self.contentSizeThatFits = $0
        }
        .frame(height: self.messageEditorHeight)
    }
    
    var disableSend: Bool {
        disableSendIfNoInput && (attributedMessage.isEmpty || isAudioRecorded)
    }
    
    private var sendButton: some View {
        Button(action: {
            self.onCommit()
            self.isAudioRecorded = false
            self.isRecordingLocked = false
        }, label: {
            Image("paper-plane")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.send))
        })
    }
    
    private var lockView: some View {
        Image("lock-solid")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
    }
    
    @State private var microphoneOffset: CGSize = .zero
    
    private var microphoneOrTrashView: some View {
        ZStack{
            if isRecordingLocked{
                Image("trash-alt")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else if isAudioRecorded{
                Circle()
                    .fill(Color.blue)
                Image("microphone-solid")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image("microphone-solid")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .ignoresSafeArea()
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom){
                VStack{
                    GeometryReader { geometry in
                        VStack{
                            if isAudioRecorded && !isRecordingLocked{
                                self.lockView
                                    .frame(height: self.messageEditorHeight)
                            }
                            Spacer(minLength: self.messageEditorHeight)
                            self.microphoneOrTrashView
                                .frame(height: self.messageEditorHeight)
                                .offset(x: 0, y: self.microphoneOffset.height)
                        }
                        .onTouchDownGesture { gesture in
                            if !self.isAudioRecorded{
                                self.isAudioRecorded = true
                                self.onRecord()
                                durationCounter.startCount()
                            }
                            self.microphoneOffset = gesture.translation
                        }
                        .onTouchUpGesture { gesture in
                            let location = gesture.location
                            if isRecordingLocked {
                                self.isAudioRecorded = false
                                self.isRecordingLocked = false
                                self.onRecordCancel()
                                durationCounter.stop()
                            } else if location.y > 0 && location.y < geometry.size.height / 2 && location.x > 0 && location.x < geometry.size.width{
                                    withAnimation {
                                        self.isRecordingLocked = true
                                    }
                            } else {
                                self.isAudioRecorded = false
                                self.onRecordEnded()
                                durationCounter.stop()
                            }
                            withAnimation {
                                self.microphoneOffset = .zero
                            }

                        }
                    }
                }
                .frame(width: 50)
                VStack{
                    if self.highlightMessage != nil {
                        self.highlightMessageView
                    }
                    HStack {
                        if isAudioRecorded{
                            self.audioInfoView
                        } else {
                            self.messageEditorView
                        }
                        self.attachmentPickerButton
                        self.sendButton
                                .disabled(disableSend)
                    }
                }
            }
        }
        .frame(height: 3 * self.messageEditorHeight)
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageComposerView(
                showAttachmentPicker: .constant(false),
                isEditing: .constant(false),
                attributedMessage: .constant(NSAttributedString(string: "New message...")),
                onCancel: {},
                onEditingChanged: { _ in },
                onRecord: {},
                onRecordEnded: {},
                onRecordCancel: {},
                onCommit: {}
            )
            .padding()
            .environment(\.colorScheme, .light)
            ZStack {
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    highlightMessage: "Message to edit",
                    onCancel: {},
                    onEditingChanged: { _ in },
                    onRecord: {},
                    onRecordEnded: {},
                    onRecordCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .light)
            }
            ZStack {
                Color.black.frame(height: 80)
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    onCancel: {},
                    onEditingChanged: { _ in },
                    onRecord: {},
                    onRecordEnded: {},
                    onRecordCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .dark)
            }
            ZStack {
                Color.black.frame(height: 152)
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    highlightMessage: "Message to edit",
                    onCancel: {},
                    onEditingChanged: { _ in },
                    onRecord: {},
                    onRecordEnded: {},
                    onRecordCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .dark)
            }
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
