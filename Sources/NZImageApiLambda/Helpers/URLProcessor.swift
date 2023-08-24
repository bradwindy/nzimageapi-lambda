//
//  File.swift
//
//
//  Created by Bradley Windybank on 30/06/23.
//

import Foundation
import RichError

class URLProcessor {
    // MARK: Internal

    struct URLProcessorError: RichError {
        typealias ErrorKind = URLProcessorErrorKind

        enum URLProcessorErrorKind: String {
            case nilCollection
            case unknownCollectionName
            case nilUrl
            case unableToEscapeUrl
            case unableToCreateFinalUrl
        }

        var kind: URLProcessorErrorKind
        var data: [String: String]
    }

    func getLargerImage(for result: NZRecordsResult) throws -> NZRecordsResult {
        guard let collection = result.collection else { throw URLProcessorError(kind: .nilCollection, data: ["result": result.customDescription()]) }
        
        switch collection {
        case "Auckland Libraries Heritage Images Collection":
            return try handleUrl(result: result, urlModifier: { url in
                guard let escapedUrlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                    throw URLProcessorError(kind: .unableToEscapeUrl, data: ["result": result.customDescription()])
                }
                
                let baseUrlString = "https://thumbnailer.digitalnz.org/?format=jpeg&src="
                let finalUrlString = baseUrlString + escapedUrlString
                
                return finalUrlString
            })
            
        case "Auckland Museum Collections":
            return try handleUrl(result: result, urlModifier: { url in
                var urlString = url.absoluteString
                
                let unneededTail = "?rendering=standard.jpg"
                
                if let tailRange = urlString.range(of: unneededTail) {
                    urlString.removeSubrange(tailRange)
                }
                
                return urlString
            })
            
        case "Te Papa Collections Online":
            return try handleUrl(result: result, urlModifier: { url in
                // Not processing these URLs yet. Need to look into this more.
                url.absoluteString
            })
            
        case "Kura Heritage Collections Online":
            return try handleUrl(result: result, urlModifier: { url in
                let startString = "/image/photos/"
                let endString = "/default.jpg"
                
                if let id = url.absoluteString.slice(from: startString, to: endString) {
                    return "https://kura.aucklandlibraries.govt.nz/iiif/2/photos:\(id)/full/2048,/0/default.jpg"
                }
                
                return url.absoluteString
            })
        
        case "Canterbury Museum":
            return try handleUrl(result: result, urlModifier: { url in
                return url.absoluteString.replacingOccurrences(of: "large", with: "xlarge")
            })
            
        
        case "Antarctica NZ Digital Asset Manager":
            //Get ID from https://antarctica.recollect.co.nz/assets/display/<ID>-600 and put into URL as such: https://antarctica.recollect.co.nz/assets/downloadwiz/<ID>
            return try handleUrl(result: result, urlModifier: { url in
                let startString = "display/"
                let endString = "-600"
                
                if let id = url.absoluteString.slice(from: startString, to: endString) {
                    return "https://antarctica.recollect.co.nz/assets/downloadwiz/\(id)"
                }
                
                return url.absoluteString
            })
            
        default:
            throw URLProcessorError(kind: .unknownCollectionName, data: ["result": result.customDescription()])
        }
    }

    // MARK: Private

    private func handleUrl(result: NZRecordsResult, urlModifier: (URL) throws -> String) throws -> NZRecordsResult {
        guard let url = result.largeThumbnailUrl else {
            throw URLProcessorError(kind: .nilUrl, data: ["result": result.customDescription()])
        }
        
        let finalUrlString = try urlModifier(url)
        
        guard let finalUrl = URL(string: finalUrlString) else {
            throw URLProcessorError(kind: .unableToCreateFinalUrl, data: ["result": result.customDescription()])
        }
        
        var modifiableResult = result
        
        modifiableResult.largeThumbnailUrl = finalUrl
        
        return modifiableResult
    }
}
