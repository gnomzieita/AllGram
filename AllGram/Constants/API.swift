//
//  API.swift
//  AllGram
//
//  Created by Admin on 11.08.2021.
//

import Foundation

struct API {
    
    /// If `true` we will get dev environment, if `false` - prod.
    /// Automatically switches between `dev` when building on simulator/device
    /// and `prod` when running TF (and AppStore in future) version
    static var inDebug: Bool {
    #if DEBUG
        return true
    #else
        return false
    #endif
    }
    
    struct Server{
        let baseURL: String
        let port: Int?
        
        func getURL() -> URL?{
            if let port = port {
                return URL(string: "\(baseURL):\(port)")
            } else {
                return URL(string: baseURL)
            }
        }
        
        func getURLwithPath(path: String) -> URL{
            if let port = port {
                return URL(string: "\(baseURL):\(port)\(path)")!
            } else {
                return URL(string: baseURL+path)!
            }
        }
    }
    
    //static let server = Server(baseURL: inDebug ? "https://dev.allgram.me" : "https://allgram.me", port: nil)
    static let server = Server(baseURL: inDebug ? "https://dev-lb.allgram.me" : "https://allgram.me", port: nil)
    
    // Strange, was https://s.allgram.me:8091 before and working (prod), needs investigation
    static let  identityServer = Server(baseURL: inDebug ? "https://s0.allgram.me" : "https://s.allgram.me", port: 9020)
    
//    static let calendarServer = Server(baseURL: inDebug ? "https://s0.allgram.me" : "https://s.allgram.me", port: 8100)
    static let botServer = Server(baseURL: inDebug ? "https://bot.allgram.me" : "https://bot-pr.allgram.me", port: 8600)
    
    // Jitsi server on AWS, without video recording
    static let jitsiServer = "jitsi.allgram.me"
    
    // a newer Jisti server with video recording, its performance was not tested with a lot of users
    static let jitsiServerJJ = "jj.allgram.me"
}

let kWidgetMatrixEventTypeString  = "m.widget"
let kWidgetModularEventTypeString = "im.vector.modular.widgets"
let kWidgetTypeJitsiV1 = "jitsi"
let kWidgetTypeJitsiV2 = "m.jitsi"
let kWidgetTypeStickerPicker = "m.stickerpicker"

