//
//  FileView.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 09.02.2022.
//

import Foundation
import SwiftUI
import MatrixSDK

struct FileView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    @State var event: MXEvent
    @State var showActionSheet: Bool = false
    @ObservedObject var downloadManager = DownloadManager()
    
    var onNeedShowInfoAlert: ((_ title: String, _ subtitle: String) -> ())?
    
    var fileName: String? {
        (event.content?["body"] as? NSMutableString) as String?
    }
    
    var sender: String{
        var sender = event.sender.components(separatedBy: ":").first ?? ""
        if sender.hasPrefix("@"){
            sender = String(sender.dropFirst())
        }
        return sender
    }
    
    func mediaURL(for event: MXEvent) -> URL? {
        event.getMediaURLs().compactMap(MXURL.init).compactMap { mediaURL in
            mediaURL.contentURL(on: API.server.getURL()!)
        }.first
    }
    
    var body: some View {
        HStack{
            Image("file-solid")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .aspectRatio(contentMode: .fill)
                .frame(width: 30)
                .padding()
            VStack(alignment: .leading){
                Text(fileName ?? "-")
                    .fontWeight(.bold)
                    .lineLimit(2)
                Text("\(sender) at \(Formatter.string(for: event.timestamp, format: .MMMdd_at_hmm))")
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Spacer()
            if downloadManager.isDownloading{
                ProgressView()
                    .frame(width: 30, height: 30)
                    .padding()
            } else {
                Button(action: {
                    if let url = mediaURL(for: event){
                        self.downloadManager.downloadFile(from: url, fileName: fileName){ response in
                            switch response {
                            case .finished:
                                self.onNeedShowInfoAlert?("Saved", "")
                            case .failure(let error):
                                self.onNeedShowInfoAlert?("Failure", error?.localizedDescription ?? "")
                            }
                        }
                    }
                }, label: {
                    Image("download-solid")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 30)
                        .padding()
                })
            }
        }
        .frame(height: 80)
    }
}
