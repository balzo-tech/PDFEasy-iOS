//
//  main.swift
//  ImageExtractor
//
//  Created by Damiaan on 13/08/2019.
//  Copyright © 2019 dPro. All rights reserved.
//

import Foundation
import PDFKit

enum PDFReadError: Error {
	case couldNotOpenPage(Int)
	case couldNotGetPageReference
	case couldNotOpenPageDictionary
	case couldNotReadResources
	case cannotCopyData
}

enum EmbeddedImage {
	case jpg(Data)
	case raw(CGImage)
}

func extractImages(from pdf: PDFDocument, extractor: @escaping (EmbeddedImage, Int, String)->Void) throws {
	for pageNumber in 0..<pdf.pageCount {
		guard let page = pdf.page(at: pageNumber) else {
			throw PDFReadError.couldNotOpenPage(pageNumber)
		}
		try extractImages(from: page) { extractor($0, pageNumber, $1) }
	}
}

func extractImages(from page: PDFPage, extractor: @escaping (EmbeddedImage, String)->Void) throws {
	guard let page = page.pageRef else {
		throw PDFReadError.couldNotGetPageReference
	}

	guard let dictionary = page.dictionary else {
		throw PDFReadError.couldNotOpenPageDictionary
	}

	guard let resources = dictionary[CGPDFDictionaryGetDictionary, "Resources"] else {
		throw PDFReadError.couldNotReadResources
	}

	if let xObject = resources[CGPDFDictionaryGetDictionary, "XObject"] {
		func iterator(key: UnsafePointer<Int8>, object: CGPDFObjectRef, info: UnsafeMutableRawPointer?) -> Bool {
			do {
				if let data = try extractImage(key: key, object: object) {
					extractor(data, String(cString: key))
				}
			} catch {
				print(error)
				return true
			}
			return true
		}
		CGPDFDictionaryApplyBlock(xObject, iterator, nil)
	}
}

enum RawDecodingError: Error {
	case cannotConstructImage
	case cannotReadSize
	case cannotReadBitsPerComponent
	case noColorSpace([String]?)
	case unkownColorSpace(String)
	case corruptColorSpace
	case noLookupTable
}

func extractImage(key: UnsafePointer<Int8>, object: CGPDFObjectRef) throws -> EmbeddedImage? {
	guard let stream: CGPDFStreamRef = object[CGPDFObjectGetValue, .stream] else { return nil }
	guard let dictionary = CGPDFStreamGetDictionary(stream) else {return nil}

	guard dictionary.getName("Subtype", CGPDFDictionaryGetName) == "Image" else {return nil}
	print(String(cString: key))

	var format = CGPDFDataFormat.raw
	guard let data = CGPDFStreamCopyData(stream, &format) else { throw PDFReadError.cannotCopyData }

	if format == .JPEG2000 || format == .jpegEncoded {
		if
			let colorSpace = try? dictionary[CGPDFDictionaryGetObject, "ColorSpace"]?.getColorSpace(),
			let provider = CGDataProvider(data: data),
			let embeddedImage = CGImage(
				jpegDataProviderSource: provider,
				decode: nil,
				shouldInterpolate: false,
				intent: .defaultIntent
			),
			let correctedImage = embeddedImage.copy(colorSpace: colorSpace)
		{
            return .raw(correctedImage)
		}
		return .jpg(data as Data)
	} else {
		return .raw( try getCGImage(data: data, info: dictionary) )
	}
}

func getCGImage(data: CFData, info: CGPDFDictionaryRef) throws -> CGImage {
	guard let colorSpace = try info[CGPDFDictionaryGetObject, "ColorSpace"]?.getColorSpace() else {
		throw RawDecodingError.noColorSpace(info.getNameArray(for: "Filter"))
	}

	guard
		let width = info[CGPDFDictionaryGetInteger, "Width"],
		let height = info[CGPDFDictionaryGetInteger, "Height"]
		else {
			throw RawDecodingError.cannotReadSize
	}
	guard let bitsPerComponent = info[CGPDFDictionaryGetInteger, "BitsPerComponent"] else {
		throw RawDecodingError.cannotReadBitsPerComponent
	}

	let decode: [CGFloat]?
	if let decodeRef = info[CGPDFDictionaryGetArray, "Decode"] {
		let count = CGPDFArrayGetCount(decodeRef)
		decode = (0..<count).map {
			decodeRef[CGPDFArrayGetNumber, $0]!
		}
	} else {
		decode = nil
	}

	guard let databuffer = CGDataProvider(data: data) else {throw RawDecodingError.cannotConstructImage}
	guard let image = CGImage(
		width: width,
		height: height,
		bitsPerComponent: bitsPerComponent,
		bitsPerPixel: bitsPerComponent * colorSpace.numberOfComponents,
		bytesPerRow: Int((Double(width * bitsPerComponent * colorSpace.numberOfComponents) / 8.0).rounded(.up)),
		space: colorSpace,
		bitmapInfo: CGBitmapInfo(),
		provider: databuffer,
		decode: decode,
		shouldInterpolate: false,
		intent: .defaultIntent
	) else {throw RawDecodingError.cannotConstructImage}

	return image
}

protocol DefaultInitializer {
	init()
}

extension Int: DefaultInitializer {}
extension CGFloat: DefaultInitializer {}

extension CGPDFObjectRef {
	func getName<K>(_ key: K, _ getter: (OpaquePointer, K, UnsafeMutablePointer<UnsafePointer<Int8>?>)->Bool) -> String? {
		guard let pointer = self[getter, key] else { return nil }
		return String(cString: pointer)
	}

	func getName<K>(_ key: K, _ getter: (OpaquePointer, K, UnsafeMutableRawPointer?)->Bool) -> String? {
		guard let pointer: UnsafePointer<UInt8> = self[getter, key] else { return nil }
		return String(cString: pointer)
	}

	subscript<R, K>(_ getter: (OpaquePointer, K, UnsafeMutablePointer<R?>)->Bool, _ key: K) -> R? {
		var result: R!
		guard getter(self, key, &result) else { return nil }
		return result
	}

	subscript<R: DefaultInitializer, K>(_ getter: (OpaquePointer, K, UnsafeMutablePointer<R>)->Bool, _ key: K) -> R? {
		var result = R()
		guard getter(self, key, &result) else { return nil }
		return result
	}

	subscript<R, K>(_ getter: (OpaquePointer, K, UnsafeMutableRawPointer?)->Bool, _ key: K) -> R? {
		var result: R!
		guard getter(self, key, &result) else { return nil }
		return result
	}

	func getNameArray(for key: String) -> [String]? {
		var object: CGPDFObjectRef!
		guard CGPDFDictionaryGetObject(self, key, &object) else { return nil }

		if let name = object.getName(.name, CGPDFObjectGetValue) {
			return [name]
		} else {
			guard let array: CGPDFArrayRef = object[CGPDFObjectGetValue, .array] else {return nil}
			var names = [String]()
			for index in 0..<CGPDFArrayGetCount(array) {
				guard let name = array.getName(index, CGPDFArrayGetName) else { continue }
				names.append(name)
			}
			assert(names.count == CGPDFArrayGetCount(array))
			return names
		}
	}

	func getColorSpace() throws -> CGColorSpace {
		if let name = getName(.name, CGPDFObjectGetValue) {
			switch name {
			case "DeviceGray":
				return CGColorSpaceCreateDeviceGray()
			case "DeviceRGB":
				return CGColorSpaceCreateDeviceRGB()
			case "DeviceCMYK":
				return CGColorSpaceCreateDeviceCMYK()
			default:
				throw RawDecodingError.unkownColorSpace(name)
			}
		} else {
			guard
				let array: CGPDFArrayRef = self[CGPDFObjectGetValue, .array],
				let name = array.getName(0, CGPDFArrayGetName)
				else {
					throw RawDecodingError.corruptColorSpace
			}

			switch name {
			case "Indexed":
				guard
					let base = try array[CGPDFArrayGetObject, 1]?.getColorSpace(),
					let hival = array[CGPDFArrayGetInteger, 2],
					hival < 256
					else {
						throw RawDecodingError.corruptColorSpace
				}
				let colorSpace: CGColorSpace?
				if let lookupTable = array[CGPDFArrayGetString, 3] {
					guard let pointer = CGPDFStringGetBytePtr(lookupTable) else { throw RawDecodingError.corruptColorSpace }
					colorSpace = CGColorSpace(indexedBaseSpace: base, last: hival, colorTable: pointer)
				} else if let lookupTable = array[CGPDFArrayGetStream, 3] {
					var format = CGPDFDataFormat.raw
					guard let data = CGPDFStreamCopyData(lookupTable, &format) else {
						throw RawDecodingError.corruptColorSpace
					}
					colorSpace = CGColorSpace(
						indexedBaseSpace: base,
						last: hival,
						colorTable: CFDataGetBytePtr(data)
					)
				} else {
					throw RawDecodingError.noLookupTable
				}
				guard let result = colorSpace else { throw RawDecodingError.corruptColorSpace }
				return result
			case "ICCBased":
				var format = CGPDFDataFormat.raw
				guard
					let stream = array[CGPDFArrayGetStream, 1],
					let info = CGPDFStreamGetDictionary(stream),
					let componentCount = info[CGPDFDictionaryGetInteger, "N"],
					let profileData = CGPDFStreamCopyData(stream, &format),
					let profile = CGDataProvider(data: profileData)
					else {
						throw RawDecodingError.corruptColorSpace
				}
				let alternate = try info[CGPDFDictionaryGetObject, "Alternate"]?.getColorSpace()
				guard let colorSpace = CGColorSpace(
					iccBasedNComponents: componentCount,
					range: nil,
					profile: profile,
					alternate: alternate
					) else {
						throw RawDecodingError.corruptColorSpace
				}
				return colorSpace
			case "Lab":
				guard
					let info = array[CGPDFArrayGetDictionary, 1],
					let whitePointRef = info[CGPDFDictionaryGetArray, "WhitePoint"]?.asFloatArray()
					else { throw RawDecodingError.corruptColorSpace }
				guard let colorSpace = CGColorSpace(
					labWhitePoint: whitePointRef,
					blackPoint: info[CGPDFDictionaryGetArray, "BlackPoint"]?.asFloatArray(),
					range: info[CGPDFDictionaryGetArray, "Range"]?.asFloatArray()
					) else {
						throw RawDecodingError.corruptColorSpace
				}
				return colorSpace
			default:
				throw RawDecodingError.unkownColorSpace(name)
			}
		}
	}

	func asFloatArray() -> [CGFloat] {
		return (0..<CGPDFArrayGetCount(self)).map {
			self[CGPDFArrayGetNumber, $0]!
		}
	}
}
