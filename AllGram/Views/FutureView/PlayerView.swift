//
//  PlayerView.swift
//  AllGram
//
//  Created by Ярослав Шерстюк on 10.09.2021.
//
// Implement Record voice https://blckbirds.com/post/voice-recorder-app-in-swiftui-1/

import SwiftUI

struct PlayerView: View {
    @State var volume = 50.0 // for example
    
    var body: some View {
        VStack {
            //TODO: Add Image Room
            Rectangle()
                .foregroundColor(Color(UIColor.secondarySystemFill))
                .cornerRadius(20)
                .frame(height: 320)
            
            Spacer()
            // Name and Date
            HStack {
                VStack(alignment: .center) {
                    Text("allgram Develop")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Aug, 2, 18:36")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemBlue))
                }
            }
            
            Spacer()
            
            VStack {
                Rectangle()
                    .frame(height: 3)
                    .cornerRadius(3)
                    .foregroundColor(Color(UIColor.secondarySystemFill))
                
                HStack {
                    Text("0:00")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    Spacer()
                    Text("4:00")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            
            Spacer()
            // Panel control
            HStack {
                Spacer()
                // Backward
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                Spacer()
                //Play
                Image(systemName: "play.fill")
                    .font(.system(size: 56))
                Spacer()
                // Forward
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                Spacer()
            }
            
            Spacer()
            // Volume
            HStack(spacing: 12) {
                Image(systemName: "volume.fill")
                Slider(value: $volume, in: 0...100)
                Image(systemName: "volume.3.fill")
            }
            
        }.padding()
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView()
    }
}
