//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case news
        case sources
        case browse
        case myApps
        case settings
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
    private var _viewDidAppear = false
    
    private var sourcesViewController: SourcesViewController!
    
    // MochiLoad: moving aurora background shown behind every tab
    private var mochiBackgroundHost: UIHostingController<MochiAuroraBackground>?
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")
        
        let browseNavigationController = self.viewControllers![Tab.browse.rawValue] as! UINavigationController
        browseNavigationController.tabBarItem.image = UIImage(systemName: "bag")
        
        let sourcesNavigationController = self.viewControllers![Tab.sources.rawValue] as! UINavigationController
        self.sourcesViewController = sourcesNavigationController.viewControllers.first as? SourcesViewController

        // MochiLoad: swap SideStore's News tab for the Learn tab (beginner explainers).
        // Same position, so the other tab indexes stay the same.
        if var tabs = self.viewControllers, tabs.count > Tab.news.rawValue
        {
            tabs[Tab.news.rawValue] = MochiLearnTab.makeNavigationController()
            self.setViewControllers(tabs, animated: false)
        }

        // MochiLoad: dark look everywhere, with the chosen accent color.
        self.overrideUserInterfaceStyle = .dark
        self.view.window?.overrideUserInterfaceStyle = .dark
        self.mochiInstallBackground()
    }
    
    // MochiLoad: keep the aurora visible when switching tabs
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem)
    {
        super.tabBar(tabBar, didSelect: item)
        DispatchQueue.main.async { self.mochiMakeSelectedTabTransparent() }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        _viewDidAppear = true
        self.mochiMakeSelectedTabTransparent()
        
        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }
    
    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }
        
        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    @objc func presentSources(_ sender: Any)
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }
            
            return
        }
                
        if let notification = (sender as? Notification), let sourceURL = notification.userInfo?[AppDelegate.addSourceDeepLinkURLKey] as? URL
        {
            self.sourcesViewController?.deepLinkSourceURL = sourceURL
        }
        
        self.selectedIndex = Tab.sources.rawValue
    }
}

// MochiLoad: let the aurora background show through the main screens. Needs proper testing per screen.
extension TabBarController
{
    fileprivate func mochiInstallBackground()
    {
        guard self.mochiBackgroundHost == nil else { return }
        
        let host = UIHostingController(rootView: MochiAuroraBackground())
        host.view.backgroundColor = UIColor(red: 11/255, green: 10/255, blue: 18/255, alpha: 1)
        host.view.isUserInteractionEnabled = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.insertSubview(host.view, at: 0)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        self.mochiBackgroundHost = host
        
        // Glassy bars so the colors show behind them too.
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        let scrolledAppearance = UINavigationBarAppearance()
        scrolledAppearance.configureWithDefaultBackground()
        scrolledAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        scrolledAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        scrolledAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        for case let navigationController as UINavigationController in self.viewControllers ?? []
        {
            navigationController.navigationBar.scrollEdgeAppearance = navigationAppearance
            navigationController.navigationBar.standardAppearance = scrolledAppearance
        }
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        self.tabBar.standardAppearance = tabAppearance
        self.tabBar.scrollEdgeAppearance = tabAppearance
    }
    
    fileprivate func mochiMakeSelectedTabTransparent()
    {
        guard let navigationController = self.selectedViewController as? UINavigationController else { return }
        navigationController.view.backgroundColor = .clear
        
        for viewController in navigationController.viewControllers
        {
            guard viewController.isViewLoaded else { continue }
            viewController.view.backgroundColor = .clear
            (viewController as? UICollectionViewController)?.collectionView.backgroundColor = .clear
            (viewController as? UITableViewController)?.tableView.backgroundColor = .clear
        }
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}
