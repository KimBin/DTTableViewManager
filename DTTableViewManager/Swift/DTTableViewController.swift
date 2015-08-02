//
//  TableViewController.swift
//  DTTableViewManager
//
//  Created by Denys Telezhkin on 12.07.15.
//  Copyright (c) 2015 Denys Telezhkin. All rights reserved.
//

import Foundation
import UIKit
import ModelStorage

public enum SupplementarySectionStyle
{
    case Title
    case View
}

public class DTTableViewController: UIViewController {
    @IBOutlet public var tableView : UITableView!

    private lazy var cellFactory: TableViewFactory = {
        precondition(self.tableView != nil, "Please call registration methods only when view is loaded")
        
        let factory = TableViewFactory(tableView: self.tableView)
        return factory
        }()
    
    public var sectionHeaderStyle = SupplementarySectionStyle.Title
    public var sectionFooterStyle = SupplementarySectionStyle.Title
    
    public var displayHeaderOnEmptySection = true
    public var displayFooterOnEmptySection = true
    
    public var insertSectionAnimation = UITableViewRowAnimation.None
    public var deleteSectionAnimation = UITableViewRowAnimation.Automatic
    public var reloadSectionAnimation = UITableViewRowAnimation.Automatic

    public var insertRowAnimation = UITableViewRowAnimation.Automatic
    public var deleteRowAnimation = UITableViewRowAnimation.Automatic
    public var reloadRowAnimation = UITableViewRowAnimation.Automatic
    
    var tableViewReactions = [TableViewReaction]()
    
    func reactionOfReactionType(type: TableViewReactionType, forCellType cellType: MirrorType?) -> TableViewReaction?
    {
        return self.tableViewReactions.filter({ (reaction) -> Bool in
            return reaction.reactionType == type && reaction.cellType?.summary == cellType?.summary
        }).first
    }
    
    public var memoryStorage : MemoryStorage!
    {
        precondition(storage is MemoryStorage, "DTTableViewController memoryStorage method should be called only if you are using MemoryStorage")
        
        return storage as! MemoryStorage
    }
    
    public var storage : StorageProtocol = {
        let storage = MemoryStorage()
        storage.supplementaryHeaderKind = DTTableViewElementSectionHeader
        storage.supplementaryFooterKind = DTTableViewElementSectionFooter
        return storage
    }()
    {
        didSet {
            if let headerFooterCompatibleStorage = storage as? BaseStorage {
                headerFooterCompatibleStorage.supplementaryHeaderKind = DTTableViewElementSectionHeader
                headerFooterCompatibleStorage.supplementaryFooterKind = DTTableViewElementSectionFooter
            }
            storage.delegate = self
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        assert(tableView != nil, "Wire up UITableView outlet before creating \(self.dynamicType) controller")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        storage.delegate = self
    }
    
    func headerModelForSectionIndex(index: Int) -> Any?
    {
        if self.storage.sections[index].numberOfObjects == 0 && !self.displayHeaderOnEmptySection
        {
            return nil
        }
        return (self.storage as? HeaderFooterStorageProtocol)?.headerModelForSectionIndex(index)
    }
    
    func footerModelForSectionIndex(index: Int) -> Any?
    {
        if self.storage.sections[index].numberOfObjects == 0 && !self.displayFooterOnEmptySection
        {
            return nil
        }
        return (self.storage as? HeaderFooterStorageProtocol)?.footerModelForSectionIndex(index)
    }
}

// MARK: Cell registration
extension DTTableViewController
{
    public func registerCellClass<T:ModelTransfer where T: UITableViewCell>(cellType:T.Type)
    {
        self.cellFactory.registerCellClass(cellType)
    }
    
    public func registerCellClass<T:ModelTransfer where T:UITableViewCell>(cellType: T.Type,
        selectionClosure: (T,T.CellModel, NSIndexPath) -> Void)
    {
        self.cellFactory.registerCellClass(cellType)
        self.whenSelected(cellType, selectionClosure)
    }

    public func registerNibNamed<T:ModelTransfer where T: UITableViewCell>(nibName: String, forCellType cellType: T.Type)
    {
        self.cellFactory.registerNibNamed(nibName, forCellType: cellType)
    }
    
    public func registerHeaderClass<T:ModelTransfer where T: UIView>(headerType : T.Type)
    {
        self.sectionHeaderStyle = .View
        self.cellFactory.registerHeaderClass(headerType)
    }
    
    public func registerFooterClass<T:ModelTransfer where T:UIView>(footerType: T.Type)
    {
        self.sectionFooterStyle = .View
        self.cellFactory.registerFooterClass(footerType)
    }
    
    public func registerNibNamed<T:ModelTransfer where T:UIView>(nibName: String, forHeaderType headerType: T.Type)
    {
        self.sectionHeaderStyle = .View
        self.cellFactory.registerNibNamed(nibName, forHeaderType: headerType)
    }
    
    public func registerNibNamed<T:ModelTransfer where T:UIView>(nibName: String, forFooterType footerType: T.Type)
    {
        self.sectionFooterStyle = .View
        self.cellFactory.registerNibNamed(nibName, forFooterType: footerType)
    }
    
}

// MARK: Table view reactions
extension DTTableViewController
{
    public func whenSelected<T:ModelTransfer where T:UITableViewCell>(cellClass:  T.Type, _ closure: (T,T.CellModel, NSIndexPath) -> Void)
    {
        var reaction = TableViewReaction(reactionType: .Selection)
        reaction.cellType = reflect(T)
        reaction.reactionBlock = { [weak self, reaction] in
            if let indexPath = reaction.reactionData as? NSIndexPath,
                let cell = self?.tableView.cellForRowAtIndexPath(indexPath),
                let model = self?.storage.objectAtIndexPath(indexPath)
            {
                closure(cell as! T, model as! T.CellModel, indexPath)
            }
        }
        self.tableViewReactions.append(reaction)
    }
    
    public func configureCell<T:ModelTransfer where T: UITableViewCell>(cellClass:T.Type, _ closure: (T, T.CellModel, NSIndexPath) -> Void)
    {
        let reaction = TableViewReaction(reactionType: .CellConfiguration)
        reaction.cellType = reflect(T)
        reaction.reactionBlock = { [weak self, reaction] in
            if let configuration = reaction.reactionData as? CellConfiguration,
                let model = self?.storage.objectAtIndexPath(configuration.indexPath)
            {
                closure(configuration.cell as! T, model as! T.CellModel, configuration.indexPath)
            }
        }
        self.tableViewReactions.append(reaction)
    }
    
    public func configureHeader<T:ModelTransfer where T: UIView>(headerClass: T.Type, _ closure: (T, T.CellModel, NSInteger) -> Void)
    {
        let reaction = TableViewReaction(reactionType: .HeaderConfiguration)
        reaction.cellType = reflect(T)
        reaction.reactionBlock = { [weak self, reaction] in
            if let configuration = reaction.reactionData as? ViewConfiguration,
                let headerStorage = self?.storage as? HeaderFooterStorageProtocol,
                let model = headerStorage.headerModelForSectionIndex(configuration.sectionIndex)
            {
                closure(configuration.view as! T, model as! T.CellModel, configuration.sectionIndex)
            }
        }
        self.tableViewReactions.append(reaction)
    }
    
    public func configureFooter<T:ModelTransfer where T: UIView>(footerClass: T.Type, _ closure: (T, T.CellModel, NSInteger) -> Void)
    {
        let reaction = TableViewReaction(reactionType: .FooterConfiguration)
        reaction.cellType = reflect(T)
        reaction.reactionBlock = { [weak self, reaction] in
            if let configuration = reaction.reactionData as? ViewConfiguration,
                let footerStorage = self?.storage as? HeaderFooterStorageProtocol,
                let model = footerStorage.footerModelForSectionIndex(configuration.sectionIndex)
            {
                closure(configuration.view as! T, model as! T.CellModel, configuration.sectionIndex)
            }
        }
        self.tableViewReactions.append(reaction)
    }
    
    public func beforeContentUpdate(block: () -> Void )
    {
        let reaction = TableViewReaction(reactionType: .ControllerWillUpdateContent)
        reaction.reactionBlock = block
        self.tableViewReactions.append(reaction)
    }
    
    public func afterContentUpdate(block : () -> Void )
    {
        let reaction = TableViewReaction(reactionType: .ControllerDidUpdateContent)
        reaction.reactionBlock = block
        self.tableViewReactions.append(reaction)
    }
}

extension DTTableViewController: UITableViewDataSource
{
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.storage.sections[section].numberOfObjects
    }
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.storage.sections.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let model = self.storage.objectAtIndexPath(indexPath)!
        let cell = self.cellFactory.cellForModel(model, atIndexPath: indexPath)
        
        if let reaction = self.reactionOfReactionType(.CellConfiguration, forCellType: reflect(cell.dynamicType)) {
            reaction.reactionData = CellConfiguration(cell:cell, indexPath:indexPath)
            reaction.perform()
        }
        return cell
    }
    
    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.sectionHeaderStyle == .View { return nil }
        
        return self.headerModelForSectionIndex(section) as? String
    }
    
    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if self.sectionFooterStyle == .View { return nil }
        
        return self.footerModelForSectionIndex(section) as? String
    }
    
    public func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        if let storage = self.storage as? MemoryStorage
        {
            if let from = storage.sections[sourceIndexPath.section] as? SectionModel,
               let to = storage.sections[destinationIndexPath.section] as? SectionModel
            {
                    let item = from.objects[sourceIndexPath.row]
                    
                    from.objects.removeAtIndex(sourceIndexPath.row)
                    to.objects.insert(item, atIndex: destinationIndexPath.row)
            }
        }
    }
}

extension DTTableViewController: UITableViewDelegate
{
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.sectionHeaderStyle == .Title { return nil }
        
        if let model = self.headerModelForSectionIndex(section) {
            let view = self.cellFactory.headerViewForModel(model)
            if let reaction = self.reactionOfReactionType(.HeaderConfiguration, forCellType: reflect(view!.dynamicType)),
                let createdView = view
            {
                reaction.reactionData = ViewConfiguration(view: createdView, sectionIndex: section)
                reaction.perform()
            }
            return view
        }
        return nil
    }
    
    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if self.sectionFooterStyle == .Title { return nil }
        
        if let model = self.footerModelForSectionIndex(section) {
            let view = self.cellFactory.footerViewForModel(model)
            if let reaction = self.reactionOfReactionType(.FooterConfiguration, forCellType: reflect(view!.dynamicType)),
                let createdView = view
            {
                reaction.reactionData = ViewConfiguration(view: createdView, sectionIndex: section)
                reaction.perform()
            }
            return view
        }
        return nil
    }
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.sectionHeaderStyle == .Title {
            if let _ = self.headerModelForSectionIndex(section) {
                return UITableViewAutomaticDimension
            }
            return CGFloat.min
        }
        
        if let _ = self.headerModelForSectionIndex(section) {
            return self.tableView.sectionHeaderHeight
        }
        return CGFloat.min
    }
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if self.sectionFooterStyle == .Title {
            if let _ = self.footerModelForSectionIndex(section) {
                return UITableViewAutomaticDimension
            }
            return CGFloat.min
        }
        
        if let _ = self.footerModelForSectionIndex(section) {
            return self.tableView.sectionFooterHeight
        }
        return CGFloat.min
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)!
        if let reaction = self.reactionOfReactionType(.Selection, forCellType: reflect(cell.dynamicType)) {
            reaction.reactionData = indexPath
            reaction.perform()
        }
    }
    
    public func objectForCell<T:ModelTransfer where T: UITableViewCell>(cell: T?, atIndexPath indexPath: NSIndexPath)-> T.CellModel?
    {
        return self.storage.objectAtIndexPath(indexPath) as? T.CellModel
    }
    
    public func objectForHeader<T:ModelTransfer where T:UIView>(headerView: T?, atSectionIndex sectionIndex: Int) -> T.CellModel?
    {
        return (self.storage as? HeaderFooterStorageProtocol)?.headerModelForSectionIndex(sectionIndex) as? T.CellModel
    }
    
    public func objectForFooter<T:ModelTransfer where T:UIView>(footerView: T?, atSectionIndex sectionIndex: Int) -> T.CellModel?
    {
        return (self.storage as? HeaderFooterStorageProtocol)?.footerModelForSectionIndex(sectionIndex) as? T.CellModel
    }
}

extension DTTableViewController : StorageUpdating
{
    public func storageDidPerformUpdate(update : StorageUpdate)
    {
        self.controllerWillUpdateContent()

        tableView.beginUpdates()
        
        tableView.deleteSections(update.deletedSectionIndexes, withRowAnimation: deleteSectionAnimation)
        tableView.insertSections(update.insertedSectionIndexes, withRowAnimation: insertSectionAnimation)
        tableView.reloadSections(update.updatedSectionIndexes, withRowAnimation: reloadSectionAnimation)
        
        tableView.deleteRowsAtIndexPaths(update.deletedRowIndexPaths, withRowAnimation: deleteRowAnimation)
        tableView.insertRowsAtIndexPaths(update.insertedRowIndexPaths, withRowAnimation: insertRowAnimation)
        tableView.reloadRowsAtIndexPaths(update.updatedRowIndexPaths, withRowAnimation: reloadRowAnimation)
        
        tableView.endUpdates()
        
        self.controllerDidUpdateContent()
    }
    
    public func storageNeedsReloading()
    {
        self.controllerWillUpdateContent()
        tableView.reloadData()
        self.controllerDidUpdateContent()
    }
    
    func controllerWillUpdateContent()
    {
        if let reaction = self.reactionOfReactionType(.ControllerWillUpdateContent, forCellType: nil)
        {
            reaction.perform()
        }
    }
    
    func controllerDidUpdateContent()
    {
        if let reaction = self.reactionOfReactionType(.ControllerDidUpdateContent, forCellType: nil)
        {
            reaction.perform()
        }
    }
}

extension DTTableViewController : TableViewStorageUpdating
{
    public func performAnimatedUpdate(block: UITableView -> Void) {
        block(self.tableView)
    }
}