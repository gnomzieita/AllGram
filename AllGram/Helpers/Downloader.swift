//
//  Downloader.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 09.02.2022.
//

import Foundation


enum DownloadError: Error{
    case fileAlreadyExists
}

// For each error type return the appropriate localized description
extension DownloadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileAlreadyExists:
            return NSLocalizedString(
                "File already exists",
                comment: "File already exists"
            )
        }
    }
}


final class DownloadManager: ObservableObject {
    @Published var isDownloading = false
    
    enum DownloadResponse{
        case finished
        case failure(Error?)
    }
    
    func downloadFile(from url: URL, fileName: String?, completionHandler: ((_ response: DownloadResponse) -> ())?) {
        isDownloading = true

        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        let destinationUrl = docsUrl?.appendingPathComponent(fileName ?? url.lastPathComponent)

        if let destinationUrl = destinationUrl {
            if FileManager().fileExists(atPath: destinationUrl.path) {
                isDownloading = false
                completionHandler?(.failure(DownloadError.fileAlreadyExists))
            } else {
                let urlRequest = URLRequest(url: url)

                let dataTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                    if let error = error {
                        self.isDownloading = false
                        completionHandler?(.failure(error))
                        return
                    }

                    guard let response = response as? HTTPURLResponse else { return }

                    if response.statusCode == 200 {
                        guard let data = data else {
                            self.isDownloading = false
                            completionHandler?(.failure(nil))
                            return
                        }
                        DispatchQueue.main.async {
                            do {
                                try data.write(to: destinationUrl, options: Data.WritingOptions.atomic)
                                self.isDownloading = false
                                completionHandler?(.finished)
                            } catch let error {
                                completionHandler?(.failure(error))
                                self.isDownloading = false
                            }
                        }
                    }
                }
                dataTask.resume()
            }
        }
    }
}
