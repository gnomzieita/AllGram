//
//  MeetingView.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import SwiftUI

enum MeetingState: String {
    case finished, started, future
}

extension MeetingInfo {
    var timeFrameText: String {
        "\(self.startDate.string(format: DateFormat.hhmm)) - \(self.endDate.string(format: DateFormat.hhmm))"
    }
    var state: MeetingState {
        let now = Date()
        if self.startDate > now {
            return .future
        } else if self.endDate < now {
            return .finished
        } else {
            return .started
        }
    }
}

struct MeetingView: View {
    let meeting: MeetingInfo
    let joinHandler: (() -> Void)?
    
    init(meeting: MeetingInfo, joinHandler: (() -> Void)?) {
        self.meeting = meeting
        self.joinHandler = joinHandler
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(verbatim: meeting.summary)
                    .font(.headline)
                    .foregroundColor(meeting.state == .started ? .white : .black)
                // Info
                HStack {
                    if meeting.state == .started {
                        Text(meeting.timeFrameText)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text(meeting.timeFrameText)
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.5))
                    }
                    Circle()
                        .frame(width: 5, height: 5)
                        .foregroundColor(.gray)
                    if meeting.state == .started {
                        Text(meeting.state.rawValue.capitalized)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                    } else {
                        Text(meeting.state.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            if let handler = joinHandler {
                Button {
                    handler()
                } label: {
                    Text("Join").bold()
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#2A2A72"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white, lineWidth: 2)
                                .opacity(meeting.state == .started ? 1 : 0)
                        )
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backColor)
                .shadow(radius: 2)
        )
    }
    
    private var backColor: Color {
        switch meeting.state {
        case .finished: return Color(hex: "#F0F0F0")
        case .started: return Color(hex: "#2A2A72")
        case .future: return Color(hex: "#FFFFFF")
        }
    }
}
