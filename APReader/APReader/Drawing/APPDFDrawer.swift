//
//  APPDFDrawer.swift
//  APReader
//
//  Created by Tangos on 2020/7/25.
//  Copyright © 2020 Tangorios. All rights reserved.
//

import Foundation
import PDFKit

enum DrawingTool: Int {
    case eraser = 0
    case pencil = 1
    case pen = 2
    case highlighter = 3
    
    var width: CGFloat {
        switch self {
        case .pencil:
            return 1
        case .pen:
            return 5
        case .highlighter:
            return 10
        default:
            return 0
        }
    }
    
    var alpha: CGFloat {
        switch self {
        case .highlighter:
            return 0.5
        default:
            return 1
        }
    }
}

class APPDFDrawer {
    weak var pdfView: PDFView!
    private var path: UIBezierPath?
    private var currentAnnotation : APDrawingAnnotation?
    private var currentPage: PDFPage?
    var color = UIColor.red // default color is red
    var drawingTool = DrawingTool.pencil
}

extension APPDFDrawer: APDrawingGestureRecognizerDelegate {
    func gestureRecognizerBegan(_ location: CGPoint) {
        guard let page = pdfView.page(for: location, nearest: true) else { return }
        beginAnnotating(for: page, in: location)
    }
    
    func gestureRecognizerMoved(_ location: CGPoint) {
        guard let currentPage = currentPage else { return }
        let nearestPage = pdfView.page(for: location, nearest: true) ?? currentPage

        if currentPage != nearestPage {
            endAnnotating(for: currentPage)
            self.currentPage = nearestPage
            beginAnnotating(for: nearestPage, in: location)
        }
        let convertedPoint = pdfView.convert(location, to: nearestPage)

        // Erasing
        if drawingTool == .eraser {
            removeAnnotationAtPoint(point: convertedPoint, page: nearestPage)
            return
        }
        
        path?.addLine(to: convertedPoint)
        path?.move(to: convertedPoint)
        drawAnnotation(onPage: nearestPage)
    }
    
    func gestureRecognizerEnded(_ location: CGPoint) {
        guard let currentPage = currentPage else { return }
        let nearestPage = pdfView.page(for: location, nearest: true) ?? currentPage
        let convertedPoint = pdfView.convert(location, to: nearestPage)
        
        // Erasing
        if drawingTool == .eraser {
            removeAnnotationAtPoint(point: convertedPoint, page: nearestPage)
            return
        }
        
        // Drawing
        guard currentAnnotation != nil else { return }
        
        path?.addLine(to: convertedPoint)
        path?.move(to: convertedPoint)
        
        // Final annotation
        endAnnotating(for: nearestPage)
    }
    
    private func beginAnnotating(for page: PDFPage, in location: CGPoint) {
        currentPage = page
        let convertedPoint = pdfView.convert(location, to: page)
        path = UIBezierPath()
        path?.move(to: convertedPoint)
    }
    
    private func endAnnotating(for page: PDFPage) {
        page.removeAnnotation(currentAnnotation!)
        createFinalAnnotation(path: path!, page: page)
        currentAnnotation = nil
    }
    
    private func createAnnotation(path: UIBezierPath, page: PDFPage) -> APDrawingAnnotation {
        let border = PDFBorder()
        border.lineWidth = drawingTool.width
        
        let annotation = APDrawingAnnotation(bounds: page.bounds(for: pdfView.displayBox), forType: .ink, withProperties: nil)
        annotation.color = color.withAlphaComponent(drawingTool.alpha)
        annotation.border = border
        return annotation
    }
    
    private func drawAnnotation(onPage: PDFPage) {
        guard let path = path else { return }
        
        if currentAnnotation == nil {
            currentAnnotation = createAnnotation(path: path, page: onPage)
        }
        
        currentAnnotation?.path = path
        forceRedraw(annotation: currentAnnotation!, onPage: onPage)
    }
    
    private func createFinalAnnotation(path: UIBezierPath, page: PDFPage) {
        let border = PDFBorder()
        border.lineWidth = drawingTool.width
        
        let bounds = CGRect(x: path.bounds.origin.x - 5,
                            y: path.bounds.origin.y - 5,
                            width: path.bounds.size.width + 10,
                            height: path.bounds.size.height + 10)
        let signingPathCentered = UIBezierPath()
        signingPathCentered.cgPath = path.cgPath
        _ = signingPathCentered.moveCenter(to: bounds.center)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = color.withAlphaComponent(drawingTool.alpha)
        annotation.border = border
        annotation.add(signingPathCentered)
        page.addAnnotation(annotation)
    }
    
    private func removeAnnotationAtPoint(point: CGPoint, page: PDFPage) {
        if let selectedAnnotation = page.annotationWithHitTest(at: point) {
            selectedAnnotation.page?.removeAnnotation(selectedAnnotation)
        }
    }
    
    private func forceRedraw(annotation: PDFAnnotation, onPage: PDFPage) {
        onPage.removeAnnotation(annotation)
        onPage.addAnnotation(annotation)
    }
}

