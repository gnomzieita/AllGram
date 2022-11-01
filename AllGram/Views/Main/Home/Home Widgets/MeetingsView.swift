//
//  MeetingsView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 17.12.2021.
//

import SwiftUI
import MatrixSDK

// MARK: - Meetings Item

struct MeetingsItemView: View {
    
    let title: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: Constants.lineWidth / 2)
                .foregroundColor(color)
                .frame(width: Constants.lineWidth)
            VStack(alignment: .leading) {
                Text(title).bold().foregroundColor(.primary).font(.system(size: Constants.fontSize))
                Text(text).foregroundColor(.gray).font(.system(size: Constants.fontSize))
            }
        }
    }
    
    struct Constants {
        static let lineWidth: CGFloat = 2
        static let fontSize: CGFloat = 12
    }
    
}

struct MeetingsItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MeetingsItemView(title: "Next Call", text: "15:00 - 15:10", color: .purple)
                .preferredColorScheme(.dark)
                .frame(maxHeight: 60)
            MeetingsItemView(title: "Status Report", text: "15:10 - 15:20", color: .yellow)
                .preferredColorScheme(.light)
                .frame(maxHeight: 60)
        }
        .previewLayout(.sizeThatFits)
    }
}

// MARK: - Meetings List

struct MeetingsView: View {
    @ObservedObject var authViewModel = AuthViewModel.shared
    @ObservedObject var viewModel: MeetingsWidgetViewModel
    
    var selectedDate: Binding<Date> {
        didSet {
            viewModel.meetingsDate = selectedDate.wrappedValue
        }
    }
    
    typealias MeetingTapHandler = (_ roomId: String) -> Void
    
    let onMeetingTap: MeetingTapHandler?
    
    init(selectedDate: Binding<Date>, onMeetingTap: MeetingTapHandler?) {
        self.selectedDate = selectedDate
        self.onMeetingTap = onMeetingTap
        self.viewModel = MeetingsWidgetViewModel(accessToken: AuthViewModel.shared.sessionVM?.accessToken ?? "nil", meetingsDate: Date())
        self.viewModel.meetingsDate = selectedDate.wrappedValue
    }
    
    var body: some View {
        ZStack{
            List {
                ForEach(viewModel.meetings) { meeting in
                    MeetingsItemView(title: meeting.summary, text: "\(meeting.startDate.string(format: DateFormat.hhmm)) - \(meeting.endDate.string(format: DateFormat.hhmm))", color: .red)
                        .onTapGesture {
                            onMeetingTap?(meeting.roomID)
                        }.listRowBackground(Color.clear)
                }
            }
            .listStyle(PlainListStyle())
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: .roomIsMeetingStateChanged, object: nil, queue: .main) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.viewModel.updateMeetings()
                }
            }
        }
    }
    
}

//struct MeetingsView_Previews: PreviewProvider {
//    @State static var selectedDate = Date()
//    static var previews: some View {
//        Group {
//            MeetingsView(selectedDate: $selectedDate)
//                .preferredColorScheme(.dark)
//                .frame(width: 150, height: 200)
//            MeetingsView(selectedDate: $selectedDate)
//                .preferredColorScheme(.light)
//                .frame(width: 150, height: 200)
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}
