//
//  APTestTableViewController.swift
//  APReader
//
//  Created by Tango on 2020/8/11.
//  Copyright © 2020 Tangorios. All rights reserved.
//

import UIKit
import MSGraphClientModels
import DZNEmptyDataSet

class APTestTableViewController: UITableViewController {
    
    private let tableCellIdentifier = "APTestTableViewCell"
    private var files: [MSGraphDriveItem]?
    public var driveItem: MSGraphDriveItem?
    
    private lazy var addFolderButtonItem = UIBarButtonItem(image: UIImage.init(named: "addfolders"), style: .plain, target: self, action: #selector(addFolderAction))
    private lazy var backBarButtonItem = UIBarButtonItem(image: UIImage.init(named: "back"), style: .plain, target: self, action: #selector(backAction))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNotification()
        loadLocalFiles(driveItem)
        setupUI()
    }
    
    func setupUI() {
        tableView.rowHeight = 100
        tableView.tableFooterView = UIView()
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        setupNavigationUI()
    }
    
    func setupNavigationUI() {
        if driveItem != nil {
            navigationItem.setLeftBarButtonItems([backBarButtonItem, addFolderButtonItem], animated: true)
        } else {
            navigationItem.setLeftBarButton(addFolderButtonItem, animated: true)
        }
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleForOpenPDFFile), name: NSNotification.Name("OpenPDFFile"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func handleForOpenPDFFile(noti: Notification) {
        if let userInfo = noti.userInfo,
            let filePath = userInfo["filePath"] as? String,
            let fileName = userInfo["fileName"] as? String {
            print("should open a pdf file: \(filePath)")
            if FileManager.default.fileExists(atPath: filePath) {
                loadLocalFiles()
                showPreviewVC(fileName)
            }
        }
    }
    
    func showPreviewVC(_ fileName: String) {
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        let previewVC: APPreviewViewController = storyBoard.instantiateViewController(identifier: "PreviewVC")
        previewVC.fileSourceType = .LOCAL
        let driveItem = MSGraphDriveItem()
        driveItem.name = fileName
        previewVC.driveItem = driveItem
        previewVC.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(previewVC, animated: true)
    }
    
    func showFileListVC(_ fileItem: MSGraphDriveItem?) {
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        let localFileListVC: APTestTableViewController = storyBoard.instantiateViewController(identifier: "LocalFileListVC")
        localFileListVC.driveItem = fileItem
        localFileListVC.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(localFileListVC, animated: true)
    }
    
    @objc
    func addFolderAction() {
        print("add folder clicked")
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        let addFolderVC: APAddFolderAlertViewController = storyBoard.instantiateViewController(identifier: "AddFolderVC")
        addFolderVC.delegate = self
        present(addFolderVC, animated: true, completion: nil)
    }
    
    @objc
    func backAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func addFileAction(_ sender: Any) {
        selectFileFromiCouldDrive()
    }
    
    func loadLocalFiles(_ driveItem: MSGraphDriveItem? = nil) {
        let manger = FileManager.default
        var cachePath: String!
        if driveItem != nil {
            cachePath = NSHomeDirectory() + "/Library/Caches/APReader.Local/File/\(driveItem?.name ?? "")"
        } else {
            cachePath = NSHomeDirectory() + "/Library/Caches/APReader.Local/File"
        }
        do {
            try manger.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("directory make failed")
        }
        do {
            files = try manger.contentsOfDirectory(atPath: cachePath).filter({ (fileName) -> Bool in
                fileName.contains(".pdf") || !fileName.contains(".")
            }).map({ (fileName) -> MSGraphDriveItem in
                let fileItem = MSGraphDriveItem()
                fileItem.name = fileName
                if !fileName.contains(".") {
                    fileItem.folder = MSGraphFolder()
                }
                return fileItem
            })
            if files?.count == 0 {
                let bundlePath = Bundle.main.path(forResource: "DevelopGuide", ofType: ".pdf")
                print("\(bundlePath ?? "")") //prints the correct path
                let destPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
                let fileManager = FileManager.default
                let fullDestPath = NSURL(fileURLWithPath: destPath).appendingPathComponent("APReader.Local/File/DevelopGuide.pdf")
                let fullDestPathString = fullDestPath?.path
                print(fileManager.fileExists(atPath: bundlePath!)) // prints true
                
                do {
                    try fileManager.copyItem(atPath: bundlePath!, toPath: fullDestPathString ?? "")
                    files = try manger.contentsOfDirectory(atPath: cachePath).filter({ (fileName) -> Bool in
                        fileName.contains(".pdf") || !fileName.contains(".")
                    }).map({ (fileName) -> MSGraphDriveItem in
                        let fileItem = MSGraphDriveItem()
                        fileItem.name = fileName
                        if !fileName.contains(".") {
                            fileItem.folder = MSGraphFolder()
                        }
                        return fileItem
                    })
                    DispatchQueue.main.async {
                        for item in self.files! {
                            print("name: \(item.name ?? "null name")")
                        }
                        self.tableView.reloadData()
                    }
                } catch {
                    print(error)
                    self.tableView.reloadData()
                }
            }
        } catch {
            print("\(error)")
        }
        
        do {
            files = try manger.contentsOfDirectory(atPath: cachePath).filter({ (fileName) -> Bool in
                fileName.contains(".pdf") || !fileName.contains(".")
            }).map({ (fileName) -> MSGraphDriveItem in
                let fileItem = MSGraphDriveItem()
                fileItem.name = fileName
                if !fileName.contains(".") {
                    fileItem.folder = MSGraphFolder()
                }
                return fileItem
            })
            DispatchQueue.main.async {
                for item in self.files! {
                    print("name: \(item.name ?? "null name")")
                }
                self.tableView.reloadData()
            }
        } catch {
            print("\(error)")
            self.tableView.reloadData()
        }
    }
    
    func createLocalFolder(_ folderName: String?) {
        guard let folderName = folderName else { return }
        let manger = FileManager.default
        let cachePath = NSHomeDirectory() + "/Library/Caches/APReader.Local/File/\(folderName)"
        do {
            try manger.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("directory create failed")
        }
    }
    
    func deleteLocalFiles(_ fileName: String?) {
        guard let fileName = fileName else { return }
        do {
            let fileManager = FileManager.default
            let destPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
            let fullDestPath = NSURL(fileURLWithPath: destPath).appendingPathComponent("APReader.Local/File/\(fileName)")
            let fullDestPathString = fullDestPath?.path
            try fileManager.removeItem(atPath: fullDestPathString ?? "")
        } catch {
            print("\(error)")
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return files?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tableCellIdentifier, for: indexPath) as! APTestTableViewCell
        cell.filename = files?[indexPath.row].name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fileItem = files?[indexPath.row]
        if fileItem?.folder == nil {
            showPreviewVC(fileItem?.name ?? "")
        } else {
            showFileListVC(fileItem)
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let index = indexPath.row
            let fileName = files?[indexPath.row].name
            files?.remove(at: index)
            tableView.deleteRows(at: [indexPath], with: .left)
            deleteLocalFiles(fileName)
        }
    }
}

extension APTestTableViewController: APAddFolderControllerDelegate {
    func didTapCreateNewFolder(_ folderName: String) {
        createLocalFolder(folderName)
        DispatchQueue.main.async {
            self.loadLocalFiles()
        }
    }
}

extension APTestTableViewController: DZNEmptyDataSetSource {
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return UIImage.init(named: "no_pdf")
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let nofilesStr = "No PDF Files"
        let noAttr = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18.0), NSAttributedString.Key.foregroundColor: UIColor.hex(0xC3C3C3)]
        return NSAttributedString(string: nofilesStr, attributes: noAttr)
    }
}

extension APTestTableViewController: DZNEmptyDataSetDelegate {
    func emptyDataSetShouldDisplay(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
}

extension APTestTableViewController {
    private func selectFileFromiCouldDrive()  {
        let documentTypes = ["com.adobe.pdf"]
        let document = UIDocumentPickerViewController.init(documentTypes: documentTypes, in: .open)
        document.delegate = self
        document.modalPresentationStyle = .automatic
        self.present(document, animated:true, completion:nil)
    }
}

extension APTestTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        guard controller.documentPickerMode == .open, url.startAccessingSecurityScopedResource() else { return }
        let fileName = url.lastPathComponent.removingPercentEncoding
        print("fileName: \(fileName!)")
        if APCloudManager.iCouldEnable() {
            APCloudManager.downloadFile(forDocumentUrl: url) { (fileData) in
                let data = fileData as NSData
                let fileManager = FileManager.default
                let docsurl = try! fileManager.url(
                    for: .cachesDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true)
                let fileUrl: URL!
                if self.driveItem?.folder != nil {
                    fileUrl = docsurl.appendingPathComponent("APReader.Local/File/\(self.driveItem?.name ?? "")/\(fileName ?? "")")
                    let exist = checkFileExists(atPath: self.driveItem?.folderItemShortRelativePath(), fileName: nil)
                    if !exist {
                        do {
                            try FileManager.default.createDirectory(atPath: docsurl.appendingPathComponent("APReader.Local/File/\(self.driveItem?.name ?? "")").path, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            print("\(error)")
                        }
                    }
                } else {
                    fileUrl = docsurl.appendingPathComponent("APReader.Local/File/\(fileName ?? "")")
                }
                data.write(to: fileUrl, atomically: true)
                DispatchQueue.main.async {
                    self.loadLocalFiles(self.driveItem)
                }
            }
        } else {
            let alert = UIAlertController(title: "Error",
                                          message: "iCloud Documents unavailable",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.dismiss(animated: true, completion: nil)
            }))
            self.present(alert, animated: true)
        }
    }
}
