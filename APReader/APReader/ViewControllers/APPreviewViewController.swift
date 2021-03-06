//
//  APPreviewViewController.swift
//  APReader
//
//  Created by Tangos on 2020/7/25.
//  Copyright © 2020 Tangorios. All rights reserved.
//

import UIKit
import PDFKit
import SVProgressHUD
import MSGraphClientModels

class APPreviewViewController: UIViewController {
    
    enum FileSourceType {
        case LOCAL
        case CLOUD
    }
    
    enum EditingMode {
        case preview
        case pen
        case text
        case comment
        case signature
    }
    
    // menu select level
    enum MenuSelectLevel {
        case root
        case middle
        case final
    }
    
    public var filePath: String?
    public var pdfDocument: PDFDocument?
    public var driveItem: MSGraphDriveItem?
    public var fileSourceType: FileSourceType? = .CLOUD
    public var signatureImage: UIImage?
    
    @IBOutlet weak var pageNumberContainer: UIView!
    @IBOutlet weak var tittleLabelContainer: UIView!
    @IBOutlet weak var pageNumberLabel: UILabel!
    @IBOutlet weak var pdfTittleLabel: UILabel!
    @IBOutlet weak var pdfView: APNonSelectablePDFView!
    @IBOutlet weak var thumbnailView: PDFThumbnailView!
    @IBOutlet weak var thumbnailViewContainer: UIView!
    @IBOutlet weak var bottomViewContainer: UIView!
    
    private lazy var backBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "back"), style: .plain, target: self, action: #selector(backAction))
    private lazy var cancelBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "cancelBtn"), style: .plain, target: self, action: #selector(cancelAction))
    private lazy var outlineBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "outline"), style: .plain, target: self, action: #selector(outlineAction))
    private lazy var thumbnailBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "thumbnail"), style: .plain, target: self, action: #selector(thunbnailAction))
    private lazy var bookmarkBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "bookmark"), style: .plain, target: self, action: #selector(bookmarkAction))
    private lazy var searchBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "search"), style: .plain, target: self, action: #selector(searchAction))
    private lazy var undoBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "undo"), style: .plain, target: self, action: #selector(undoAction))
    private lazy var redoBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "redo"), style: .plain, target: self, action: #selector(redoAction))
    
    private lazy var tapGestureRecognizer = UITapGestureRecognizer()
    private lazy var pdfDrawingGestureRecognizer = APDrawingGestureRecognizer()
    private lazy var pdfTextDrawingGestureRecognizer = APTextDrawingGestureRecognizer()
    private lazy var pdfCommentDrawingGestureRecognizer = APCommentDrawingGestureRecognizer()
    
    private var toolbarActionControl: APPDFToolbarActionControl?
    private var editButtonClicked: Bool = false
    private var commentButtonClicked: Bool = false
    private var needUpload: Bool = false
    private var tappedOnComment: Bool = false
    private var count = 0
    private var timer: APRepeatingTimer?
    private var currentSelectedAnnotation: PDFAnnotation?
    
    private let pdfDrawer = APPDFDrawer()
    private let pdfTextDrawer = APPDFTextDrawer()
    private let pdfCommentDrawer = APPDFCommentDrawer()
    
    private var editingMode: EditingMode? = .preview
    private var editingColor: UIColor? = .red
    private var menuSelectLevel: MenuSelectLevel? = .root {
        didSet {
            updateBottomContainer()
        }
    }
    
    private lazy var bottomMenu: APPreviewBottomMenu = {
        let bottomMenu = APPreviewBottomMenu.initInstanceFromXib()
        bottomMenu.frame.size.height = 54
        bottomMenu.frame.origin.x = bottomViewContainer.frame.origin.x
        bottomMenu.width = view.width
        bottomMenu.delegate = self
        return bottomMenu
    }()
    private lazy var edittorMenu: APPreviewEditorMenu = {
        let edittorMenu = APPreviewEditorMenu.initInstanceFromXib()
        edittorMenu.frame.size.height = 54
        edittorMenu.frame.origin.x = bottomViewContainer.frame.origin.x
        edittorMenu.width = view.width
        edittorMenu.delegate = self
        return edittorMenu
    }()
    private lazy var penControlMenu: APPreviewPenToolMenu = {
        let penControlMenu = APPreviewPenToolMenu.initInstanceFromXib()
        penControlMenu.frame.size.height = 54
        penControlMenu.frame.origin.x = bottomViewContainer.frame.origin.x
        penControlMenu.width = view.width
        penControlMenu.delegate = self
        return penControlMenu
    }()
    
    // MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStates()
        setupPDFView()
        loadPdfFile()
        setupUI()
        registerNotification()
    }
    
    override var prefersStatusBarHidden: Bool {
        if editButtonClicked {
            return false
        } else {
            return navigationController?.isNavigationBarHidden == true
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        needUpload = false
        
        guard let signatureImage = signatureImage, let page = pdfView.currentPage else { return }
        let pageBounds = page.bounds(for: .cropBox)
        let imageBounds = CGRect(x: pageBounds.midX, y: pageBounds.midY, width: 200, height: 100)
        let imageStamp = APImageStampAnnotation(with: signatureImage, forBounds: imageBounds, withProperties: nil)
        page.addAnnotation(imageStamp)
        
        registerNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(pdfViewPageChanged), name: .PDFViewPageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(extractAnnotation(notification:)), name: .PDFViewAnnotationHit, object: nil)
    }
    
    private func setupUI() {
        navigationController?.hidesBarsOnTap = false
        navigationItem.setLeftBarButtonItems([backBarButtonItem, outlineBarButtonItem, thumbnailBarButtonItem], animated: true)
        navigationItem.setRightBarButtonItems([bookmarkBarButtonItem, searchBarButtonItem], animated: true)
        if pdfDocument?.outlineRoot == nil {
            outlineBarButtonItem.isEnabled = false
        }
        pdfTittleLabel.text = pdfDocument?.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? pdfDocument?.documentURL?.lastPathComponent
        
        updatePageNumberLabel()
        
        toolbarActionControl = APPDFToolbarActionControl(pdfPreviewController: self)
        tapGestureRecognizer = UITapGestureRecognizer()
        tapGestureRecognizer.addTarget(self, action: #selector(tappedAction(sender:)))
        pdfView.addGestureRecognizer(tapGestureRecognizer)
        setupBottomMenuContainer()
        menuSelectLevel = .root
    }
    
    func setupBottomMenuContainer() {
        bottomMenu = APPreviewBottomMenu.initInstanceFromXib()
        bottomMenu.frame.size.height = 54
        bottomMenu.frame.origin.x = bottomViewContainer.frame.origin.x
        bottomMenu.width = view.width
        bottomMenu.delegate = self
        
        edittorMenu = APPreviewEditorMenu.initInstanceFromXib()
        edittorMenu.frame.size.height = 54
        edittorMenu.frame.origin.x = bottomViewContainer.frame.origin.x
        edittorMenu.width = view.width
        edittorMenu.delegate = self
    }
    
    func updateBottomContainer() {
        var bottomView: UIView!
        for view in bottomViewContainer.subviews {
            view.removeFromSuperview()
        }
        switch menuSelectLevel {
        case .root:
            bottomView = bottomMenu
        case .middle:
            bottomView = edittorMenu
        case .final:
            bottomView = penControlMenu
        default:
            bottomView = bottomMenu
        }
        bottomViewContainer.addSubview(bottomView)
    }
    
    func updateLeftNavigationBarButtons() {
        switch menuSelectLevel {
        case .root:
            navigationItem.setLeftBarButtonItems([backBarButtonItem, outlineBarButtonItem, thumbnailBarButtonItem], animated: true)
            navigationItem.setRightBarButtonItems([bookmarkBarButtonItem, searchBarButtonItem], animated: true)
            if editingMode == .comment {
                navigationItem.setLeftBarButtonItems([cancelBarButtonItem], animated: true)
                navigationItem.setRightBarButtonItems([bookmarkBarButtonItem, searchBarButtonItem, redoBarButtonItem, undoBarButtonItem], animated: true)
            } else if editingMode == .preview {
                navigationItem.setLeftBarButtonItems([backBarButtonItem, outlineBarButtonItem, thumbnailBarButtonItem], animated: true)
                navigationItem.setRightBarButtonItems([bookmarkBarButtonItem, searchBarButtonItem], animated: true)
            }
        case .middle, .final:
            navigationItem.setLeftBarButtonItems([cancelBarButtonItem], animated: true)
            if editingMode == .preview {
                navigationItem.setLeftBarButtonItems([backBarButtonItem, outlineBarButtonItem, thumbnailBarButtonItem], animated: true)
            }
            navigationItem.setRightBarButtonItems([bookmarkBarButtonItem, searchBarButtonItem, redoBarButtonItem, undoBarButtonItem], animated: true)
        default:
            navigationItem.setLeftBarButtonItems([backBarButtonItem, outlineBarButtonItem, thumbnailBarButtonItem], animated: true)
        }
    }
    
    func setupStates() {
        switch editingMode {
        case .preview:
            editingColor = pdfDrawer.color
        case .pen:
            editingColor = pdfDrawer.color
        case .text:
            editingColor = pdfTextDrawer.color
        default:
            editingColor = pdfDrawer.color
        }
    }
    
    private func setupPDFView() {
        pdfView.displayDirection = .horizontal
        pdfView.displayMode = .singlePage
        pdfView.usePageViewController(true)
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        pdfView.autoScales = true
        pdfView.backgroundColor = view.backgroundColor!
        
        thumbnailView.pdfView = pdfView
        thumbnailView.thumbnailSize = CGSize(width: 44, height: 54)
        thumbnailView.layoutMode = .horizontal
        thumbnailView.backgroundColor = thumbnailViewContainer.backgroundColor!
        thumbnailView.isHidden = true
        thumbnailViewContainer.isHidden = true
        
        pdfDrawer.pdfView = pdfView
        pdfTextDrawer.pdfView = pdfView
        pdfCommentDrawer.pdfView = pdfView
        
        pdfDrawer.delegate = self
        pdfTextDrawer.delegate = self
        pdfCommentDrawer.delegate = self
        
        undoBarButtonItem.isEnabled = pdfDrawer.changesManager.undoEnable
        redoBarButtonItem.isEnabled = pdfDrawer.changesManager.redoEnable
        
        let panAnnotationGesture = UIPanGestureRecognizer(target: self, action: #selector(didPanAnnotation(sender:)))
        pdfView.addGestureRecognizer(panAnnotationGesture)
    }
    
    private func loadPdfFile() {
        let pdfDocument = PDFDocument(url: self.getFileUrl()!)
        pdfView.document = pdfDocument
        self.pdfDocument = pdfDocument
    }
    
    // MARK: -  Action
    
    @objc func extractAnnotation(notification: Notification) {
        print("userInfo: \(notification.userInfo ?? [:])")
        if let note = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation {
            print(note)
            if note.isKind(of: APCommentImageStampAnnotation.self) || (note.type == "Stamp" && note.contents == "Comment") {
                print("click APCommentImageStampAnnotation")
                if editingMode != .comment {
                    guard let page = pdfView.currentPage, let index = pdfView.document?.index(for: page) else { return }
                    showCommentViewController(in: note.bounds.origin, pageIndex: index) { (shouldAddAnnotation, shouldRemoveAnnotation) in
                        print("tapped on comment in extractAnnotation")
                        if shouldRemoveAnnotation {
                            page.removeAnnotation(note)
                        }
                        self.addTimer()
                        self.tappedOnComment = false
                    }
                }
                tappedOnComment = true
            } else if note.isKind(of: APImageStampAnnotation.self) {
                print("click APImageStampAnnotation")
            } else if note.isKind(of: APWidgetAnnotation.self) {
                print("click APWidgetAnnotation")
            } else {
                print("click APDrawingAnnotation")
            }
        }
    }
    
    @objc
    func tappedAction(sender: UITapGestureRecognizer) {
        print("tapped")
        if commentButtonClicked { return }
        if sender == pdfCommentDrawingGestureRecognizer { return }
        UIView.transition(with: self.bottomViewContainer, duration: 0.25, options: .transitionCrossDissolve, animations: {
            self.navigationController?.setNavigationBarHidden(!(self.navigationController?.isNavigationBarHidden ?? false) , animated: true)
            self.bottomViewContainer.isHidden = !self.bottomViewContainer.isHidden
            self.pageNumberContainer.isHidden = !self.pageNumberContainer.isHidden
            self.tittleLabelContainer.isHidden = !self.tittleLabelContainer.isHidden
        }, completion: nil)
    }
    
    @objc
    func backAction(_ sender: Any) {
        stopTimer()
        if fileSourceType == .CLOUD {
            uploadPDFFileToOneDrive()
        }
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc
    func didPanAnnotation(sender: UIPanGestureRecognizer) {
        let touchLocation = sender.location(in: pdfView)
        guard let page = pdfView.page(for: touchLocation, nearest: true) else {
            return
        }
        let locationOnPage = pdfView.convert(touchLocation, to: page)
        switch sender.state {
        case .began:
            guard let annotation = page.annotation(at: locationOnPage) else {
                return
            }
            if annotation.isKind(of: PDFAnnotation.self) {
                currentSelectedAnnotation = annotation
            }
        case .changed:
            guard let annotation = currentSelectedAnnotation else {
                return
            }
            let initialBounds = annotation.bounds
            annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
            print("move to \(locationOnPage)")
            
        case .ended, .cancelled, .failed:
            currentSelectedAnnotation = nil
        default:
            break
        }
    }
    
    @objc
    func cancelAction(_ sender: Any) {
        
        pdfView.removeGestureRecognizer(pdfDrawingGestureRecognizer)
        pdfView.removeGestureRecognizer(pdfTextDrawingGestureRecognizer)
        pdfView.removeGestureRecognizer(pdfCommentDrawingGestureRecognizer)
        
        if editButtonClicked && menuSelectLevel == .final {
            menuSelectLevel = .middle
            updateLeftNavigationBarButtons()
            tittleLabelContainer.isHidden = false
            tapGestureRecognizer = UITapGestureRecognizer()
            tapGestureRecognizer.addTarget(self, action: #selector(tappedAction(sender:)))
            pdfView.addGestureRecognizer(tapGestureRecognizer)
            pdfDrawer.changesManager.clear()
            pdfDrawer.delegate?.pdfDrawerDidFinishDrawing()
            editButtonClicked = !editButtonClicked
        } else if menuSelectLevel == .final {
            menuSelectLevel = .middle
            updateLeftNavigationBarButtons()
        } else {
            menuSelectLevel = .root
            stopTimer()
            updateLeftNavigationBarButtons()
        }
    }
    
    @objc
    func outlineAction(_ sender: Any) {
        print("Click outline")
        toolbarActionControl?.showOutlineTableForPFDDocument(for: pdfDocument, from: sender)
    }
    
    @objc
    func thunbnailAction(_ sender: Any) {
        print("Click thumbnail")
        thumbnailViewContainer.isHidden = !thumbnailViewContainer.isHidden
        thumbnailView.isHidden = !thumbnailView.isHidden
        bottomViewContainer.isHidden = !bottomViewContainer.isHidden
    }
    
    @objc
    func editAction() {
        print("editAction tapped")
        editButtonClicked = !editButtonClicked
        if editButtonClicked {
            needUpload = true
            tittleLabelContainer.isHidden = true
            menuSelectLevel = .final
            addTimer()
        }
    }
    
    func commentInBottomMenuAction(_ sender: UIButton) {
        print("commentAction tapped")
        commentButtonClicked = !commentButtonClicked
        if commentButtonClicked {
            editingMode = .comment
            updateLeftNavigationBarButtons()
            tittleLabelContainer.isHidden = true
            pdfView.removeGestureRecognizer(tapGestureRecognizer)
            pdfCommentDrawingGestureRecognizer = APCommentDrawingGestureRecognizer()
            pdfCommentDrawingGestureRecognizer.addTarget(self, action: #selector(shouldShowCommentViewController(sender:)))
            pdfView.addGestureRecognizer(pdfCommentDrawingGestureRecognizer)
            sender.setImage(UIImage.init(named: "comment-sel"), for: .normal)
            addTimer()
            bottomMenu.disableButtonArray()
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            editingMode = .preview
            updateLeftNavigationBarButtons()
            tittleLabelContainer.isHidden = false
            pdfView.removeGestureRecognizer(pdfCommentDrawingGestureRecognizer)
            tapGestureRecognizer = UITapGestureRecognizer()
            tapGestureRecognizer.addTarget(self, action: #selector(tappedAction(sender:)))
            pdfView.addGestureRecognizer(tapGestureRecognizer)
            sender.setImage(UIImage.init(named: "comment"), for: .normal)
            bottomMenu.enableButtonArray()
            pdfCommentDrawer.changesManager.clear()
            pdfCommentDrawer.delegate?.pdfCommentDrawerDidFinishDrawing()
            navigationItem.leftBarButtonItem?.isEnabled = true
        }
    }
    
    func showCommentViewController(in location: CGPoint, pageIndex: Int, complementionHanlder: @escaping (Bool, Bool) -> Void) {
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        let commentContentVC: APCommentContentViewController = storyBoard.instantiateViewController(identifier: "CommentContentVC")
        commentContentVC.modalPresentationStyle = .fullScreen
        commentContentVC.fileName = driveItem?.name
        commentContentVC.pageIndex = pageIndex
        commentContentVC.location = location
        commentContentVC.actionHanlder = complementionHanlder
        present(commentContentVC, animated: true)
    }
    
    @objc
    func shouldShowCommentViewController(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sender.view)
        guard let page = pdfView.page(for: location, nearest: true), let index = pdfView.document?.index(for: page) else { return }
        let convertPoint = pdfView.convert(location, to:page)
        let convertedPoint = CGPoint(x: Double(String(format:"%.3f", convertPoint.x)) ?? 0, y: Double(String(format:"%.3f", convertPoint.y)) ?? 0)
        showCommentViewController(in: convertedPoint, pageIndex: index) { (shouldAddAnnotation, shouldRemoveAnnotation) in
            if shouldAddAnnotation && !self.tappedOnComment {
                let imageBounds = CGRect(x: convertedPoint.x, y: convertedPoint.y, width: 30, height: 30)
                let imageStamp = APCommentImageStampAnnotation(forBounds: imageBounds, withProperties: nil)
                imageStamp.contents = "Comment"
                page.addAnnotation(imageStamp)
                self.pdfCommentDrawer.changesManager.addWidgetAnnotation(imageStamp, forPage: page)
                self.pdfCommentDrawer.delegate?.pdfCommentDrawerDidFinishDrawing()
            } else {
                print("tapped on comment")
                self.tappedOnComment = false
            }
            self.addTimer()
        }
    }
    
    func textInputInBottomMenuAction(_ sender: UIButton) {
        if editButtonClicked {
            editingMode = .text
            pdfView.removeGestureRecognizer(tapGestureRecognizer)
            sender.setImage(UIImage.init(named: "edit_done"), for: .normal)
            penControlMenu.disableButtonArray()
            pdfTextDrawingGestureRecognizer = APTextDrawingGestureRecognizer()
            pdfTextDrawingGestureRecognizer.addTarget(self, action: #selector(shouldShowTextInputViewController(sender:)))
            pdfView.addGestureRecognizer(pdfTextDrawingGestureRecognizer)
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            editingMode = .preview
            pdfView.addGestureRecognizer(tapGestureRecognizer)
            sender.setImage(UIImage.init(named: "edit_begin"), for: .normal)
            penControlMenu.enableButtonArray()
            navigationItem.leftBarButtonItem?.isEnabled = true
        }
        editButtonClicked = !editButtonClicked
    }
    
    func showTextCreateAlert(complementionHanlder: @escaping (Bool, String) -> Void) {
        var nameTextField: UITextField?
        
        let alertController = UIAlertController(
            title: "Create Text Annotation",
            message: "",
            preferredStyle: UIAlertController.Style.alert)
        
        let createAction = UIAlertAction(title: "Create", style: .default) { (action) -> Void in
            
            if let text = nameTextField?.text, text.count > 0 {
                print("text input = \(text)")
                complementionHanlder(true, text)
                self.dismiss(animated: true, completion: nil)
            } else {
                print("No text entered")
                SVProgressHUD.showError(withStatus: "No folder name entered")
                complementionHanlder(false, "")
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            self.dismiss(animated: true, completion: nil)
        }
        
        alertController.addTextField {
            (folderName) -> Void in
            nameTextField = folderName
            nameTextField!.placeholder = "Text annotation"
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(createAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc
    func shouldShowTextInputViewController(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sender.view)
        guard let page = pdfView.page(for: location, nearest: true) else { return }
        let convertedPoint = pdfView.convert(location, to:page)
        
        showTextCreateAlert { (shouldShow, text) in
            if shouldShow {
                let textAnnotation = PDFAnnotation(bounds: CGRect(x: convertedPoint.x, y: convertedPoint.y, width: 120, height: 30), forType: .freeText, withProperties: nil)
                textAnnotation.contents = text
                textAnnotation.font = UIFont.systemFont(ofSize: 18.0)
                textAnnotation.fontColor = self.pdfTextDrawer.color
                textAnnotation.color = .clear
                page.addAnnotation(textAnnotation)
                
                self.pdfTextDrawer.changesManager.addWidgetAnnotation(textAnnotation, forPage: page)
                self.pdfTextDrawer.delegate?.pdfTextDrawerDidFinishDrawing()
            }
        }
    }
    
    @objc
    func bookmarkAction(_ sender: Any) {
        print("Click bookmark")
        toolbarActionControl?.showBookmarkTable(from: sender)
    }
    
    @objc
    func searchAction(_ sender: Any) {
        print("click search")
        toolbarActionControl?.showSearchViewController(for: self.pdfDocument, from: sender)
    }
    
    @objc
    func undoAction() {
        print("undo action tapped")
        switch editingMode {
        case .comment:
            pdfCommentDrawer.undoAction()
        case .pen:
            pdfDrawer.undoAction()
        case .text:
            pdfTextDrawer.undoAction()
        case .preview:
            print("in preview mode")
        default:
            print("undo action")
        }
    }
    
    @objc
    func redoAction() {
        print("redo action tapped")
        pdfDrawer.redoAction()
        switch editingMode {
        case .comment:
            pdfCommentDrawer.redoAction()
        case .pen:
            pdfDrawer.redoAction()
        case .text:
            pdfTextDrawer.redoAction()
        case .preview:
            print("in preview mode")
        default:
            print("redo Action")
        }
    }
    
//    @IBAction func pageUpAction(_ sender: Any) {
//        print("page up action")
//        pdfView.goToPreviousPage(sender)
//    }
//
//    @IBAction func pageDownAction(_ sender: Any) {
//        print("page down action")
//        pdfView.goToNextPage(sender)
//    }
    
    func didSelectPdfOutline(_ pdfOutline: PDFOutline?) {
        if let pdfOutline = pdfOutline {
            pdfView.go(to: (pdfOutline.destination?.page)!)
        }
    }
    
    func didSelectPdfPageFromBookmark(_ pdfPage: PDFPage?) {
        if let page = pdfPage {
            pdfView.go(to: page)
        }
    }
    
    func didSelectPdfSelection(_ pdfSelection: PDFSelection?) {
        if let selection = pdfSelection {
            selection.color = .yellow
            pdfView.currentSelection = selection
            pdfView.go(to: selection)
        }
    }
    
    func didSelectColorInColorPicker(_ color: UIColor?) {
        if let color = color {
            switch editingMode {
            case .comment:
                pdfCommentDrawer.color = color
            case .pen:
                pdfDrawer.color = color
            case .text:
                pdfTextDrawer.color = color
            case .preview:
                pdfDrawer.color = color
            default:
                print("update color")
            }
            
            editingColor = color
            penControlMenu.updateColorBtnColor(color)
            edittorMenu.updateColorBtnColor(color)
        }
    }
    
    // MARK: - Notification Events
    
    @objc func pdfViewPageChanged(_ notification: Notification) {
        updatePageNumberLabel()
    }
    
    func getFileUrl() -> URL? {
        switch fileSourceType {
        case .LOCAL:
            guard let driveItem = driveItem else { return nil }
            return driveItem.localFolderFilePath()
        case .CLOUD:
            guard let driveItem = driveItem else { return nil }
            return driveItem.localFilePath()
        default:
            guard let driveItem = driveItem else { return nil }
            return driveItem.localFilePath()
        }
    }
    
    func updatePageNumberLabel() {
        guard let currentPage = pdfView.currentPage,
            let index = pdfView.document?.index(for: currentPage),
            let pageCount = pdfView.document?.pageCount else {
                pageNumberLabel.text = nil
                return
        }
        pageNumberLabel.text = "\(index + 1)/\(pageCount)"
    }
}

extension APPreviewViewController: APPDFDrawerDelegate {
    func pdfDrawerDidFinishDrawing() {
        undoBarButtonItem.isEnabled = pdfDrawer.changesManager.undoEnable
        redoBarButtonItem.isEnabled = pdfDrawer.changesManager.redoEnable
    }
}

extension APPreviewViewController: APPDFTextDrawerDelegate {
    func pdfTextDrawerDidFinishDrawing() {
        undoBarButtonItem.isEnabled = pdfTextDrawer.changesManager.undoEnable
        redoBarButtonItem.isEnabled = pdfTextDrawer.changesManager.redoEnable
    }
}

extension APPreviewViewController: APPDFCommentDrawerDelegate {
    func pdfCommentDrawerDidFinishDrawing() {
        undoBarButtonItem.isEnabled = pdfCommentDrawer.changesManager.undoEnable
        redoBarButtonItem.isEnabled = pdfCommentDrawer.changesManager.redoEnable
    }
}

extension APPreviewViewController: APPreviewBottomMenuDelegate {
    func didSelectMark() {
        print("didSelectComment")
        menuSelectLevel = .middle
        editingMode = .preview
        updateLeftNavigationBarButtons()
        addTimer()
    }
    
    func didSelectComment(_ sender: UIButton) {
        commentInBottomMenuAction(sender)
    }
    
//    func didSelectSignature() {
//        print("didSelectSignature")
//        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
//        let signatureVC: APSignatureViewController = storyBoard.instantiateViewController(identifier: "SignatureVC")
//        signatureVC.previousViewController = self
//        editingMode = .signature
//        navigationController?.pushViewController(signatureVC, animated: true)
//    }
}

extension APPreviewViewController: APPreviewEditorMenuDelegate {
//    func didSelectCommentAction(_ sender: UIButton) {
//        commentInBottomMenuAction(sender)
//    }
    
    func didSelectPenAction(_ sender: UIButton) {
        menuSelectLevel = .final
        
        editAction()
    }
    
    func didSelectTextEditAction(_ sender: UIButton) {
        let tag = sender.tag
        editingMode = .pen
        switch tag {
        case 2:
            pdfDrawer.addAnnotation(.highlight, markUpType: .highlight)
        case 3:
            pdfDrawer.addAnnotation(.underline, markUpType: .underline)
        case 4:
            pdfDrawer.addAnnotation(.strikeOut, markUpType: .strikeOut)
        default:
            print("HighLight")
        }
    }
    
    func didSelectColorInEditorMenu(_ sender: UIButton) {
        toolbarActionControl?.showColorPickerViewController(editingColor!, from: sender)
    }
}

extension APPreviewViewController: APPreviewPenToolMenuDelegate {
    func didSelectPenControl(_ selectedValue: DrawingTool) {
        if editButtonClicked {
            editingMode = .pen
            pdfView.removeGestureRecognizer(tapGestureRecognizer)
            pdfDrawingGestureRecognizer = APDrawingGestureRecognizer()
            pdfView.addGestureRecognizer(pdfDrawingGestureRecognizer)
            pdfDrawingGestureRecognizer.drawingDelegate = pdfDrawer
            penControlMenu.disableButtonArray()
            pdfDrawer.drawingTool = selectedValue
        } else {
            pdfView.removeGestureRecognizer(pdfDrawingGestureRecognizer)
            pdfView.removeGestureRecognizer(pdfTextDrawingGestureRecognizer)
            tapGestureRecognizer = UITapGestureRecognizer()
            tapGestureRecognizer.addTarget(self, action: #selector(tappedAction(sender:)))
            pdfView.addGestureRecognizer(tapGestureRecognizer)
            penControlMenu.enableButtonArray()
        }
        editButtonClicked = !editButtonClicked
    }
    
    func didSelectTextInputMode(_ sender: UIButton) {
        editingMode = .text
        textInputInBottomMenuAction(sender)
    }
    
    func didSelectColorinPenTool(_ sender: UIButton) {
        toolbarActionControl?.showColorPickerViewController(editingColor!, from: sender)
    }
}

// MARK: - Auto Saving

extension APPreviewViewController {
    func uploadPDFFileToOneDrive() {
        guard let selectedFileName = filePath, needUpload == true  else {
            return
        }
        SVProgressHUD.showInfo(withStatus: "Uploading to OneDrive")
        APOneDriveManager.instance.createUploadSession(filePath: driveItem?.fileItemShortRelativePath(), fileName: selectedFileName, completion: { (result: OneDriveManagerResult, uploadUrl, expirationDateTime, nextExpectedRanges) -> Void in
            switch(result) {
            case .Success:
                print("success on creating session (\(String(describing: uploadUrl)) (\(String(describing: expirationDateTime))")
                APOneDriveManager.instance.uploadPDFBytes(driveItem: self.driveItem!, uploadUrl: uploadUrl!, completion: { (result: OneDriveManagerResult, webUrl, fileId) -> Void in
                    switch(result) {
                    case .Success:
                        print ("Web Url of file \(String(describing: webUrl))")
                        print ("FileId of file \(String(describing: fileId))")
                        SVProgressHUD.showInfo(withStatus: "Upload Succeed")
                    case .Failure(let error):
                        print("\(error)")
                        SVProgressHUD.showInfo(withStatus: "Upload Failed")
                    }
                })
            case .Failure(let error):
                print("\(error)")
            }
        })
    }
    
    func savePDFDocument() {
        switch editingMode {
        case .comment:
            if !pdfCommentDrawer.changesManager.undoEnable {
                return
            }
        case .text:
            if !pdfTextDrawer.changesManager.undoEnable {
                return
            }
        case .pen:
            if !pdfDrawer.changesManager.undoEnable {
                return
            }
        default:
            print("saving the changes")
        }
        
        print("\(Date()) savePDFDocument")
        let copyPdfDoc = pdfDocument!.copy() as! PDFDocument
        DispatchQueue.global(qos: .background).sync { [weak self] in
            if let data = copyPdfDoc.dataRepresentation() {
                try? data.write(to: (self?.getFileUrl())!, options: .atomicWrite)
            }
        }
    }
    
    func addTimer() {
        timer = APRepeatingTimer(timeInterval: 5)
        timer?.eventHandler = { [weak self] in
            print("\(Date()) timer running")
            self?.savePDFDocument()
        }
        timer?.resume()
    }
    
    func stopTimer() {
        timer?.suspend()
    }
}
