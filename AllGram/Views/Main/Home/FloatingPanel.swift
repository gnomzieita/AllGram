//
//  FloatingPanel.swift
//  AllGram
//
//  Created by Admin on 18.08.2021.
//

import SwiftUI

struct FloatingActionLabel: View {
    
    var text: String
    var imageName: String
    var iconBackgroundColor: Color?
    var iconTintColor: Color?
    
    static let estimatedHeight: CGFloat = Constants.vPadding * 2 + Constants.iconSize
    
    var body: some View {
        Label(
            title: {
                Text(text)
                    .foregroundColor(.primary)
                    .font(.system(size: Constants.fontSize))
            },
            icon: {
                ZStack{
                    Circle()
                        .foregroundColor(iconBackgroundColor ?? .clear)
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                    Image(imageName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(iconTintColor)
                        .frame(width: Constants.iconSize * 0.6, height: Constants.iconSize * 0.6)
                }
            }
        )
        .padding(.vertical, Constants.vPadding)
        .padding(.horizontal, Constants.hPadding)
    }
    
    struct Constants {
        static let iconSize: CGFloat = 44
        static let fontSize: CGFloat = 16
        static let vPadding: CGFloat = 1
        static let hPadding: CGFloat = 16
    }
    
}

struct FloatingPanel: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    let arrowUp: Bool
    let bottomSpace: CGFloat?
    var onNeedOpenRoom: ((_ roomID: String) -> ())?
    
    @State private var showingNewMeeting = false
    @State private var showingJoinMeeting = false
    @State private var showingHelp = false
    
    /// Estimated height for cap and options
    static let estimatedHeight: CGFloat = estimatedCapHeight + estimatedOptionsHeight
    
    /// Arrow height + its v padding + stack v top padding + spacing to options
    static let estimatedCapHeight: CGFloat = Constants.arrowHeight + Constants.arrowPadding * 2 + Constants.vStackTopPadding  + Constants.vStackSpacing
    /// 2 actions height + spacing between + stack v bottom padding
    static let estimatedOptionsHeight: CGFloat = 2 * FloatingActionLabel.estimatedHeight + Constants.vStackSpacing + Constants.vStackBotPadding
    
    var body: some View {
        ZStack {
            panelContent
                .background(Color.floatingPanelBackgroundColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cornerRadius(Constants.cornerRadius, corners: [.topLeft, .topRight])
        .shadow(radius: 2)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.15))
//        .sheet(isPresented: $showingNewMeeting) {
//            NewMeetingView(session: authViewModel.session, onNeedOpenRoom: {roomID in
//                self.onNeedOpenRoom?(roomID)
//            })
//        }
        .sheet(isPresented: $showingJoinMeeting) {
            JoinMeetingView(session: authViewModel.session!, onNeedOpenRoom: { roomID in
                self.onNeedOpenRoom?(roomID)
            })
        }
        .sheet(isPresented: $showingHelp) {
            SimpleWebView(title: "Help", url: "https://www.allgram.com/help")
        }
    }
    
    private var panelContent : some View {
        VStack(alignment: .leading, spacing: Constants.vStackSpacing) {
            HStack {
                Spacer()
                Image(systemName: "chevron.\(arrowUp ? "up" : "down")")
                    .resizable().scaledToFit()
                    .frame(height: Constants.arrowHeight)
                Spacer()
            }
            .padding(.vertical, Constants.arrowPadding)
            Button(action: { showingNewMeeting.toggle() }, label: {
                FloatingActionLabel(text: "New Meeting", imageName: "handshake", iconBackgroundColor: .pink, iconTintColor: .white)
            })
            Button(action: { showingJoinMeeting.toggle() }, label: {
                FloatingActionLabel(text: "Join Meeting", imageName: "sign-in-alt-solid", iconBackgroundColor: .green, iconTintColor: .white)
            })
            if let space = bottomSpace {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: space)
            }
        }
        .padding(.top, Constants.vStackTopPadding)
        .padding(.bottom, Constants.vStackBotPadding)
    }
    
    struct Constants {
        static let cornerRadius: CGFloat = 36
        static let vStackSpacing: CGFloat = 10
        static let arrowHeight: CGFloat = 12
        static let arrowPadding: CGFloat = 8
        static let vStackTopPadding: CGFloat = 8
        static let vStackBotPadding: CGFloat = 16
    }
    
}

struct FloatingPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Image("homeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    FloatingPanel(arrowUp: false, bottomSpace: nil)
                }
            }
            .preferredColorScheme(.dark)
            .previewDevice("iPhone 11")
            ZStack {
                Image("homeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    FloatingPanel(arrowUp: false, bottomSpace: nil)
                }
            }
            .preferredColorScheme(.light)
            .previewDevice("iPhone 8 Plus")
        }
    }
}
