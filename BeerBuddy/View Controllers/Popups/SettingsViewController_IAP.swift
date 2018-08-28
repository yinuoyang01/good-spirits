//
//  SettingsViewController_IAP.swift
//  Good Spirits
//
//  Created by Alexei Baboulevitch on 2018-8-26.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

import Foundation
import StoreKit

extension SettingsViewController: SKProductsRequestDelegate, SKPaymentTransactionObserver
{
    func requestProducts()
    {
        if self.products != nil
        {
            return
        }
        else if self.productsRequest != nil
        {
            return
        }
        else
        {
            appDebug("IAP requesting products...")
            let productsRequest = SKProductsRequest(productIdentifiers: [ Constants.tipIAPProductID ])
            productsRequest.delegate = self
            self.productsRequest = productsRequest
            productsRequest.start()
        }
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
    {
        self.productsRequest = nil
        self.products = response.products
        
        appDebug("IAP products retrieved!")
        
        for invalidID in response.invalidProductIdentifiers
        {
            appError("found invalid product ID in \(invalidID)")
            return
        }
        
        reloadIAPCells()
    }
    
    func reloadIAPCells()
    {
        self.tableView.beginUpdates()
        let iap = sectionCounts.index { $0.0 == .iap }!
        let meta = sectionCounts.index { $0.0 == .meta }!
        updateCell(nil, forRowAt: IndexPath.init(row: 2, section: meta))
        updateFooter(tableView.footerView(forSection: iap), forSection: iap)
        self.tableView.endUpdates()
    }
    
    func purchase()
    {
        if paymentInProgress
        {
            return
        }
        
        if let product = self.products?.first
        {
            let payment = SKMutablePayment(product: product)
            SKPaymentQueue.default().add(payment)
            
            self.paymentInProgress = true
            reloadIAPCells()
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    {
        appDebug("IAP updated transactions: \(transactions)")
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                appDebug("purchasing...")
                break
            case .purchased:
                appDebug("purchased!")
                Defaults.donated = true
                self.paymentInProgress = false
                reloadIAPCells()
                queue.finishTransaction(transaction)
                break
            case .failed:
                appDebug("failed!")
                if (transaction.error as NSError?)?.code == 0
                {
                    appAlert("Can't connect to the iTunes Store. Are you sure you're on a data network?", self)
                }
                else if (transaction.error as NSError?)?.code == SKError.paymentCancelled.rawValue
                {
                    appDebug("payment cancelled")
                }
                else
                {
                    appAlert("The transaction has failed: \((transaction.error!).localizedDescription)", self)
                }
                self.paymentInProgress = false
                reloadIAPCells()
                queue.finishTransaction(transaction)
                break
            case .deferred:
                appDebug("deferred!")
                appAlert("Your purchase is waiting to be approved.")
                break
            case .restored:
                self.paymentInProgress = false
                reloadIAPCells()
                queue.finishTransaction(transaction)
                break
            }
        }
    }
    
    public func requestDidFinish(_ request: SKRequest)
    {
        self.productsRequest = nil
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error)
    {
        self.productsRequest = nil
    }
    
    func localizedPrice() -> String?
    {
        if let product = self.products?.first
        {
            let formatter = NumberFormatter()
            formatter.formatterBehavior = .behavior10_4
            formatter.numberStyle = .currency
            formatter.locale = product.priceLocale
            
            return formatter.string(from: product.price)
        }
        else
        {
            return nil
        }
    }
}
