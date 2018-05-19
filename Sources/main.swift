//
//  main.swift
//  SplitPDF
//
//  Created by Lieven Dekeyser on 18/05/2018.
//  Copyright © 2018 Plane Tree Software. All rights reserved.
//

import Foundation
import CoreGraphics

enum SplitPDFError: Int32, Error {
	case invalidInput = 1
	case invalidOutput
	
	var localizedDescription: String {
		switch self {
		case .invalidInput:
			return "Invalid input"
		case .invalidOutput:
			return "Invalid output"
		}
	}
}

func SplitPDF(inputURL: URL, outputURL: URL) throws {
	guard let inputDocument = CGPDFDocument(inputURL as CFURL) else {
		throw SplitPDFError.invalidInput
	}
	
	guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
		throw SplitPDFError.invalidOutput
	}
	
	let inputPages = inputDocument.numberOfPages
	let outputPages = 2 * inputPages 
	for i in 0 ..< outputPages {
		let inputPageIndex: Int
		if i < inputPages {
			inputPageIndex = i
		} else {
			inputPageIndex = outputPages - i - 1
		}
	
		guard let page = inputDocument.page(at: inputPageIndex + 1) else {
			continue
		}
		
		let inputMediaBox = page.getBoxRect(.mediaBox)
		
		var outputMediaBox: CGRect
		if inputMediaBox.width > inputMediaBox.height {
			outputMediaBox = CGRect(x: 0.0, y: 0.0, width: 0.5 * inputMediaBox.width, height: inputMediaBox.height)
		} else {
			outputMediaBox = CGRect(x: 0.0, y: 0.0, width: inputMediaBox.width, height: 0.5 * inputMediaBox.height)
		}
		
		pdfContext.beginPage(mediaBox: &outputMediaBox)
		if i % 2 == 1 {
			pdfContext.translateBy(x: inputMediaBox.origin.x, y: inputMediaBox.origin.y)
			pdfContext.drawPDFPage(page)
		} else {
			pdfContext.translateBy(x: inputMediaBox.origin.x - (inputMediaBox.size.width - outputMediaBox.size.width), y: inputMediaBox.origin.y - (inputMediaBox.size.height - outputMediaBox.size.height))
			pdfContext.drawPDFPage(page)
		}
		pdfContext.endPage()
	}
	
	pdfContext.closePDF()
}

let args = CommandLine.arguments
guard args.count > 1 else {
	print("Usage: SplitPDF <inputPath> <outputPath>?")
	exit(0)
}

let inputURL = URL(fileURLWithPath: args[1])	
let outputURL: URL
if args.count > 2 {
	outputURL = URL(fileURLWithPath: args[2])
} else {
	let baseName = inputURL.deletingPathExtension().lastPathComponent
	outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(baseName.appending("-split.pdf"))
}

do {
	try SplitPDF(inputURL: inputURL, outputURL: outputURL)
} catch let error as SplitPDFError {
	fputs("\(error.localizedDescription)\n", stderr)
	exit(error.rawValue)
} catch {
	print("Unknown error: \(error.localizedDescription)")
	exit(-1)
}
