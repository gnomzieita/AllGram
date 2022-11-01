//
//  EditorOptionsView.swift
//  AllGram
//
//  Created by Alex Pirog on 06.06.2022.
//

import SwiftUI

/// Provides a scrollable stack of video editor options
struct EditorOptionsView: View {
    let editOptions: [EditOption]
    let editHandler: (EditOption) -> Void
    
    init(options: [EditOption] = EditOption.allCases, handler: @escaping (EditOption) -> Void) {
        self.editOptions = options
        self.editHandler = handler
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(EditOption.allCases, id: \.title) { option in
                    EditOptionView(type: option) { tapOption in
                        editHandler(tapOption)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .background(Color.gray)
    }
    
    struct EditOptionView: View {
        let type: EditOption
        let action: (EditOption) -> Void
        
        var body: some View {
            Button { action(type) } label: {
                VStack {
                    Image(type.imageName)
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundColor(Color(.cyan))
                    Text(type.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    enum EditOption: CaseIterable {
        case trim, rotateL, rotateR, flipV, flipH, clear
        
        var imageName: String {
            switch self {
            case .trim: return "cut-solid"
            case .rotateL: return "retweet-solid"
            case .rotateR: return "retweet-solid"
            case .flipV: return "arrows-alt-v-solid"
            case .flipH: return "arrows-alt-h-solid"
            case .clear: return "broom-solid"
            }
        }
        
        var title: String {
            switch self {
            case .trim: return "Trim"
            case .rotateL: return "Rotate L"
            case .rotateR: return "Rotate R"
            case .flipV: return "Flip V"
            case .flipH: return "Flip H"
            case .clear: return "Clear"
            }
        }
    }
}
