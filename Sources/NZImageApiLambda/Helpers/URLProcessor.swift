//
//  File.swift
//
//
//  Created by Bradley Windybank on 30/06/23.
//

import Foundation
import RichError

class URLProcessor {
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
            
        default:
            throw URLProcessorError(kind: .unknownCollectionName, data: ["result": result.customDescription()])
        }
    }
    
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
    
    /*
     guard let escapedUrlString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
         throw URLProcessorError(kind: .unableToEscapeUrl, data: ["result": result.customDescription()])
     }
     
     let baseUrlString = "https://thumbnailer.digitalnz.org/?format=jpeg&src="
     let finalUrlString = baseUrlString + escapedUrlString
     */
}
