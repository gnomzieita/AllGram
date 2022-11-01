//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import MatrixSDK

/// `DataSource` is the base class for data sources managed by MatrixKit.
/// Inherited 'DataSource' instances are used to handle table or collection data.
/// They may conform to UITableViewDataSource or UICollectionViewDataSource protocol to be used as data source delegate
/// for a UITableView or a UICollectionView instance.
class DataSource {
    /// The delegate notified when the data has been updated.
    weak var delegate: DataSourceProtocol?
    
    // MARK: - Life cycle
    
    init() {
        state = .unknown
        cellDataMap = [:]
    }
    
    // MARK: - Life cycle
    /// Base constructor of data source.
    /// Customization like class registrations must be done before loading data (see '[MXKDataSource registerCellDataClass: forCellIdentifier:]') .
    /// That is why 3 steps should be considered during 'MXKDataSource' initialization:
    /// 1- call [MXKDataSource initWithMatrixSession:] to initialize a new allocated object.
    /// 2- customize classes and others...
    /// 3- call [MXKDataSource finalizeInitialization] to finalize the initialization.
    /// - Parameter mxSession: the Matrix session to get data from.
    /// - Returns: the newly created instance.
    convenience init(matrixSession: MXSession?) {
        self.init()
        mxSession = matrixSession
        state = .preparing
    }
    
    /// Finalize the initialization by adding an observer on matrix session state change.
    func finalizeInitialization() {
        // Add an observer on matrix session state change (prevent multiple registrations).
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.mxSessionStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didMXSessionStateChange(_:)), name: NSNotification.Name.mxSessionStateDidChange, object: nil)
        
        // Call the registered callback to finalize the initialisation step.
        didMXSessionStateChange()
    }
    
    // MARK: - MXSessionStateDidChangeNotification
    
    @objc func didMXSessionStateChange(_ notif: Notification?) {
        // Check this is our Matrix session that has changed
        if (notif?.object as? MXSession) == mxSession {
            didMXSessionStateChange()
        }
    }
    
    /// This method is called when the state of the attached Matrix session has changed.
    func didMXSessionStateChange() {
        // The inherited class is highly invited to override this method for its business logic
    }
    
    // MARK: - MXKCellData classes
    /// Register the MXKCellData class that will be used to process and store data for cells
    /// with the designated identifier.
    /// - Parameters:
    ///   - cellDataClass: a MXKCellData-inherited class that will handle data for cells.
    ///   - identifier: the identifier of targeted cell.
    
    // MARK: - MXKCellData classes
    
    func registerCellDataClass(_ cellDataClass: AnyClass, forCellIdentifier identifier: String?) {
        // Sanity check: accept only MXKCellData classes or sub-classes
        assert(cellDataClass.isSubclass(of: MXKCellData.self), "Invalid parameter not satisfying: cellDataClass.isSubclass(of: MXKCellData.self)")
        
        cellDataMap?[identifier ?? ""] = cellDataClass
    }
    
    /// Return the MXKCellData class that handles data for cells with the designated identifier.
    /// - Parameter identifier: the cell identifier.
    /// - Returns: the associated MXKCellData-inherited class.
    func cellDataClass(forCellIdentifier identifier: String?) -> AnyClass {
        return cellDataMap?[identifier ?? ""]
    }
    
    // MARK: - MXKCellRenderingDelegate
    
    func cell(_ cell: MXKCellRendering?, didRecognizeAction actionIdentifier: String?, userInfo: [AnyHashable : Any]?) {
        // The data source simply relays the information to its delegate
        if delegate != nil && delegate?.responds(to: #selector(MXKDataSourceDelegate.dataSource(_:didRecognizeAction:inCell:userInfo:))) ?? false {
            delegate?.dataSource?(self, didRecognizeAction: actionIdentifier, inCell: cell, userInfo: userInfo)
        }
    }
    
        func cell(_ cell: MXKCellRendering?, shouldDoAction actionIdentifier: String?, userInfo: [AnyHashable : Any]?, defaultValue: Bool) -> Bool {
            var shouldDoAction = defaultValue
            
            // The data source simply relays the question to its delegate
            if delegate != nil && delegate?.responds(to: #selector(MXKDataSourceDelegate.dataSource(_:shouldDoAction:inCell:userInfo:defaultValue:))) ?? false {
                shouldDoAction = delegate?.dataSource?(self, shouldDoAction: actionIdentifier, inCell: cell, userInfo: userInfo, defaultValue: defaultValue) ?? false
            }
            
            return shouldDoAction
        }
        
        // MARK: - Pending HTTP requests
        
        /// Cancel all registered requests.
        
        // MARK: - Pending HTTP requests
        /// Cancel all registered requests.
        func cancelAllRequests() {
            // The inherited class is invited to override this method
        }
}

protocol DataSourceProtocol: AnyObject {
    /// Ask the delegate which MXKCellRendering-compliant class must be used to render this cell data.
    /// This method is called when MXKDataSource instance is used as the data source delegate of a table or a collection.
    /// CAUTION: The table or the collection MUST have registered the returned class with the same identifier than the one returned by [cellReuseIdentifierForCellData:].
    /// - Parameter cellData: the cell data to display.
    /// - Returns: a MXKCellRendering-compliant class which inherits UITableViewCell or UICollectionViewCell class (nil if the cellData is not supported).
    func cellViewClass(for cellData: MXKCellData?) -> AnyClass & MXKCellRendering
    /// Ask the delegate which identifier must be used to dequeue reusable cell for this cell data.
    /// This method is called when MXKDataSource instance is used as the data source delegate of a table or a collection.
    /// CAUTION: The table or the collection MUST have registered the right class with the returned identifier (see [cellViewClassForCellData:]).
    /// - Parameter cellData: the cell data to display.
    /// - Returns: the reuse identifier for the cell (nil if the cellData is not supported).
    func cellReuseIdentifier(for cellData: MXKCellData?) -> String?
    /// Tells the delegate that some cell data/views have been changed.
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - changes: contains the index paths of objects that changed.
    func dataSource(_ dataSource: DataSourceProtocol?, didCellChange changes: Any?)
}

extension DataSourceProtocol {
    /// Tells the delegate that data source state changed
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - state: the new data source state.
    func dataSource(_ dataSource: DataSource?, didStateChange state: DataSourceState) {}
    /// Relevant only for data source which support multi-sessions.
    /// Tells the delegate that a matrix session has been added.
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - mxSession: the new added session.
    func dataSource(_ dataSource: DataSource?, didAddMatrixSession mxSession: MXSession?) {}
    /// Relevant only for data source which support multi-sessions.
    /// Tells the delegate that a matrix session has been removed.
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - mxSession: the removed session.
    func dataSource(_ dataSource: DataSource?, didRemoveMatrixSession mxSession: MXSession?) {}
    /// Tells the delegate when a user action is observed inside a cell.
    /// - seealso: `MXKCellRenderingDelegate` for more details.
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - actionIdentifier: an identifier indicating the action type (tap, long press...) and which part of the cell is concerned.
    ///   - cell: the cell in which action has been observed.
    ///   - userInfo: a dict containing additional information. It depends on actionIdentifier. May be nil.
    func dataSource(_ dataSource: DataSource?, didRecognizeAction actionIdentifier: String?, inCell cell: MXKCellRendering?, userInfo: [AnyHashable : Any]?)
    /// Asks the delegate if a user action (click on a link) can be done.
    /// - seealso: `MXKCellRenderingDelegate` for more details.
    /// - Parameters:
    ///   - dataSource: the involved data source.
    ///   - actionIdentifier: an identifier indicating the action type (link click) and which part of the cell is concerned.
    ///   - cell: the cell in which action has been observed.
    ///   - userInfo: a dict containing additional information. It depends on actionIdentifier. May be nil.
    ///   - defaultValue: the value to return by default if the action is not handled.
    /// - Returns: a boolean value which depends on actionIdentifier.
    func dataSource(_ dataSource: DataSource?, shouldDoAction actionIdentifier: String?, inCell cell: MXKCellRendering?, userInfo: [AnyHashable : Any]?, defaultValue: Bool) -> Bool
}
