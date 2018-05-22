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

enum PageOrder: String {
	case natural
	case booklet
}

extension PageOrder {
	func inputPage(outputPageIndex: Int, totalInputPages: Int) -> (inputPageIndex: Int, first: Bool) {
		switch self {
		case .natural:
			return (inputPageIndex: outputPageIndex/2, first: (outputPageIndex % 2 == 0))
		case .booklet:
			let inputPageIndex: Int
			if outputPageIndex < totalInputPages {
				inputPageIndex = outputPageIndex
			} else {
				inputPageIndex = 2*totalInputPages - outputPageIndex - 1
			}
			return (inputPageIndex: inputPageIndex, first: (outputPageIndex % 2) == 1)
		}
	}
}

func SplitPDF(inputURL: URL, outputURL: URL, pageOrder: PageOrder) throws {
	guard let inputDocument = CGPDFDocument(inputURL as CFURL) else {
		throw SplitPDFError.invalidInput
	}
	
	guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
		throw SplitPDFError.invalidOutput
	}
	
	let inputPages = inputDocument.numberOfPages
	let outputPages = 2 * inputPages 
	for i in 0 ..< outputPages {
		let (inputPageIndex, first) = pageOrder.inputPage(outputPageIndex: i, totalInputPages: inputPages)
	
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
		if first {
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



struct Arguments {
	var inputURL: URL
	var outputURL: URL
	var pageOrder: PageOrder = .natural
}

enum Option: String {
	case order = "-order"
}

extension Arguments {
	init?(args: [String]) {
		var iterator = args.makeIterator()
		guard iterator.next() != nil else {
			return nil
		}
		
		var inputPathArg: String?
		var outputPathArg: String?
		var pageOrder = PageOrder.natural
		
		while let arg = iterator.next() {
			if arg.starts(with: "-") {
				guard let option = Option(rawValue: arg) else {
					return nil
				}
				switch option {
				case .order:
					guard let orderString = iterator.next(), let order = PageOrder(rawValue: orderString) else {
						return nil
					}
					pageOrder = order
				}
			} else if inputPathArg == nil {
				inputPathArg = arg
			} else if outputPathArg == nil {
				outputPathArg = arg
			}
		}
		
		guard let inputPath = inputPathArg else {
			return nil
		}
		
		let inputURL = URL(fileURLWithPath: inputPath)
		let outputURL: URL
		if let outputPath = outputPathArg {
			outputURL = URL(fileURLWithPath: outputPath)
		} else {
			let baseName = inputURL.deletingPathExtension().lastPathComponent
			outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(baseName.appending("-split.pdf"))
		}
		
		
		self.init(inputURL: inputURL, outputURL: outputURL, pageOrder: pageOrder)
	}
}

guard let args = Arguments(args: CommandLine.arguments) else {
	print("Usage: SplitPDF [-order natural|booklet]? <inputPath> <outputPath>?")
	exit(0)
}

do {
	try SplitPDF(inputURL: args.inputURL, outputURL: args.outputURL, pageOrder: args.pageOrder)
} catch let error as SplitPDFError {
	fputs("\(error.localizedDescription)\n", stderr)
	exit(error.rawValue)
} catch {
	print("Unknown error: \(error.localizedDescription)")
	exit(-1)
}
