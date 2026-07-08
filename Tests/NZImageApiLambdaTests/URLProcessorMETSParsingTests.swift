//
//  URLProcessorMETSParsingTests.swift
//
//  Coverage for the two Rosetta METS parsers (already `internal`, not `private`, precisely so
//  they're directly unit-testable): URLProcessor.largestTapuhiJP2PID (TAPUHI/NDHA) and
//  URLProcessor.warArtMasterFLPID (War Art Online). Both parse synthetic `<mets:amdSec>` blocks
//  rather than real Rosetta responses — no network involved.
//

import XCTest
@testable import NZImageApiLambda

final class URLProcessorMETSParsingTests: XCTestCase {
    /// Builds one `<mets:amdSec ID="<pid>-amd">` block carrying a MIME type and byte size, the
    /// shape both parsers scan for.
    private func amdSecBlock(pid: String, mime: String, sizeBytes: Int64) -> String {
        """
        <mets:amdSec ID="\(pid)-amd">
            <key id="fileMIMEType">\(mime)</key>
            <key id="fileSizeBytes">\(sizeBytes)</key>
        </mets:amdSec>
        """
    }

    private func mets(_ blocks: [String]) -> String {
        "<mets:mets>\(blocks.joined())</mets:mets>"
    }

    // MARK: largestTapuhiJP2PID

    func testLargestTapuhiJP2PIDPicksLargestUnderCap() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/jp2", sizeBytes: 1000),
            amdSecBlock(pid: "FL2", mime: "image/jp2", sizeBytes: 5000),
        ])

        XCTAssertEqual(URLProcessor.largestTapuhiJP2PID(inMETS: metsXML, maxBytes: 10000), "FL2")
    }

    func testLargestTapuhiJP2PIDSkipsTiffAndJpegBlocks() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 999_999),
            amdSecBlock(pid: "FL2", mime: "image/jpeg", sizeBytes: 500_000),
            amdSecBlock(pid: "FL3", mime: "image/jp2", sizeBytes: 2000),
        ])

        XCTAssertEqual(URLProcessor.largestTapuhiJP2PID(inMETS: metsXML, maxBytes: 10000), "FL3")
    }

    func testLargestTapuhiJP2PIDExcludesJP2sOverCap() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/jp2", sizeBytes: 50000),
            amdSecBlock(pid: "FL2", mime: "image/jp2", sizeBytes: 3000),
        ])

        XCTAssertEqual(URLProcessor.largestTapuhiJP2PID(inMETS: metsXML, maxBytes: 10000), "FL2")
    }

    func testLargestTapuhiJP2PIDReturnsNilWhenNoJP2Present() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 999_999),
            amdSecBlock(pid: "FL2", mime: "image/jpeg", sizeBytes: 500_000),
        ])

        XCTAssertNil(URLProcessor.largestTapuhiJP2PID(inMETS: metsXML, maxBytes: 10000))
    }

    func testLargestTapuhiJP2PIDReturnsNilForMalformedXML() {
        XCTAssertNil(URLProcessor.largestTapuhiJP2PID(inMETS: "not xml at all, no amdSec blocks here", maxBytes: 10000))
    }

    // MARK: warArtMasterFLPID

    func testWarArtMasterFLPIDReturnsNilWhenNoTIFFUnderCap() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/jpeg", sizeBytes: 500_000),
        ])

        XCTAssertNil(
            URLProcessor.warArtMasterFLPID(inMETS: metsXML, maxBytes: 10000, accessPassthroughThreshold: 700_000)
        )
    }

    func testWarArtMasterFLPIDReturnsTIFFWhenPDFBlockPresentRegardlessOfLargeJPEG() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 5000),
            amdSecBlock(pid: "FL2", mime: "application/pdf", sizeBytes: 100),
            // Even a JPEG at/above the passthrough threshold must not suppress the TIFF pick
            // once a PDF compilation is present — the PDF branch is checked first.
            amdSecBlock(pid: "FL3", mime: "image/jpeg", sizeBytes: 900_000),
        ])

        XCTAssertEqual(
            URLProcessor.warArtMasterFLPID(inMETS: metsXML, maxBytes: 10000, accessPassthroughThreshold: 700_000),
            "FL1"
        )
    }

    func testWarArtMasterFLPIDReturnsNilWhenAccessJPEGAtOrAboveThreshold() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 5000),
            amdSecBlock(pid: "FL2", mime: "image/jpeg", sizeBytes: 900_000),
        ])

        XCTAssertNil(
            URLProcessor.warArtMasterFLPID(inMETS: metsXML, maxBytes: 10000, accessPassthroughThreshold: 700_000)
        )
    }

    func testWarArtMasterFLPIDReturnsTIFFForThumbnailTierAccessJPEG() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 5000),
            amdSecBlock(pid: "FL2", mime: "image/jpeg", sizeBytes: 500_000),
        ])

        XCTAssertEqual(
            URLProcessor.warArtMasterFLPID(inMETS: metsXML, maxBytes: 10000, accessPassthroughThreshold: 700_000),
            "FL1"
        )
    }

    func testWarArtMasterFLPIDPicksLargestTIFFUnderCap() {
        let metsXML = mets([
            amdSecBlock(pid: "FL1", mime: "image/tiff", sizeBytes: 2000),
            amdSecBlock(pid: "FL2", mime: "image/tiff", sizeBytes: 50000), // over cap, excluded
            amdSecBlock(pid: "FL3", mime: "image/tiff", sizeBytes: 8000),
            amdSecBlock(pid: "FL4", mime: "image/jpeg", sizeBytes: 500_000),
        ])

        XCTAssertEqual(
            URLProcessor.warArtMasterFLPID(inMETS: metsXML, maxBytes: 10000, accessPassthroughThreshold: 700_000),
            "FL3"
        )
    }
}
