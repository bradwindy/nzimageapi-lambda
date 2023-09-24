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
            case unableToFindRecollectDomain
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
                ripId(from: url,
                      to: { "https://kura.aucklandlibraries.govt.nz/iiif/2/photos:\($0)/full/2048,/0/default.jpg" },
                      startString: "/image/photos/",
                      endString: "/default.jpg")
            })
        
        case "Canterbury Museum",
             "Culture Waitaki":
            return try handleUrl(result: result, urlModifier: { url in
                url.absoluteString.replacingOccurrences(of: "large", with: "xlarge")
            })
            
        case "Antarctica NZ Digital Asset Manager",
             "Tauranga City Libraries Other Collection",
             "Upper Hutt City Library Heritage Collections",
             "Presbyterian Research Centre",
             "National Army Museum",
             "Wellington City Recollect",
             "Tāmiro":
            
            return try handleUrl(result: result, urlModifier: { url in
                try recollectDownloadUrlString(from: url, collection: collection)
            })
            
        case "National Publicity Studios black and white file prints",
             "Picture Wairarapa",
             "South Canterbury Museum",
             "Howick Historical Village NZMuseums",
             "Waimate Museum and Archives PastPerfect",
             "Te Toi Uku, Crown Lynn and Clayworks Museum",
             "Te Hikoi Museum",
             "V.C. Browne & Son NZ Aerial Photograph Collection":
            return try handleUrl(result: result, urlModifier: { url in
                url.absoluteString
            })
            
        case "Hawke's Bay Knowledge Bank":
            return try handleUrl(result: result, urlModifier: { url in
                var urlString = url.absoluteString
                
                if urlString.numberOfOccurrences(of: "-") > 1 {
                    let dashPosition = urlString.count - 12
                    let startIndex = urlString.index(urlString.startIndex, offsetBy: dashPosition)
                    let endIndex = urlString.index(urlString.startIndex, offsetBy: dashPosition + 7)
                    urlString.removeSubrange(startIndex ... endIndex)
                }
                
                return urlString
            })
            
        case "Auckland Art Gallery Toi o Tāmaki":
            return try handleUrl(result: result, urlModifier: { url in
                url.absoluteString.replacingOccurrences(of: "medium", with: "xlarge")
            })
            
        default:
            throw URLProcessorError(kind: .unknownCollectionName, data: ["result": result.customDescription()])
        }
    }

    // MARK: Private

    private let recollectDomainMap = ["Antarctica NZ Digital Asset Manager": "antarctica.recollect.co.nz",
                                      "Tauranga City Libraries Other Collection": "paekoroki.tauranga.govt.nz",
                                      "Upper Hutt City Library Heritage Collections": "uhcl.recollect.co.nz",
                                      "Presbyterian Research Centre": "prc.recollect.co.nz",
                                      "National Army Museum": "nam.recollect.co.nz",
                                      "Wellington City Recollect": "wellington.recollect.co.nz",
                                      "Tāmiro": "massey.recollect.co.nz"]

    private func recollectDownloadUrlString(from url: URL, collection: String) throws -> String {
        let domain = try recollectDomain(for: collection)
        
        return ripId(from: url,
                     to: { "https://\(domain)/assets/downloadwiz/\($0)" },
                     startString: "display/",
                     endString: "-600")
    }
    
    private func recollectDomain(for collection: String) throws -> String {
        guard let domain = recollectDomainMap[collection] else {
            throw URLProcessorError(kind: .unableToFindRecollectDomain, data: ["collection": collection])
        }
        
        return domain
    }
    
    private func ripId(from url: URL, to: (String) -> String, startString: String, endString: String) -> String {
        guard let id = url.absoluteString.slice(from: startString, to: endString) else { return url.absoluteString }
        return to(id)
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
}
