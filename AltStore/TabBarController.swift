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

        // MochiLoad: swap SideStore's News tab for Home (setup status, expiry, refresh, explainers).
        // Same position, so the other tab indexes stay the same.
        if var tabs = self.viewControllers, tabs.count > Tab.news.rawValue
        {
            tabs[Tab.news.rawValue] = MochiHomeTab.makeNavigationController()
            self.setViewControllers(tabs, animated: false)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.mochiRefreshAllApps(_:)), name: .mochiRefreshAllApps, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.mochiOpenPairing(_:)), name: .mochiOpenPairing, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.mochiOpenSettings(_:)), name: .mochiOpenSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.mochiOpenMyApps(_:)), name: .mochiOpenMyApps, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.mochiAppDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        // MochiLoad: dark look everywhere, with the chosen accent color.
        self.overrideUserInterfaceStyle = .dark
        self.view.window?.overrideUserInterfaceStyle = .dark
        self.mochiInstallBackground()
        
        // MochiLoad: keep the aurora visible when switching tabs. (Overriding tabBar(_:didSelect:) and
        // calling super crashed on recent iOS, where UITabBarController no longer implements it.)
        if self.delegate == nil
        {
            self.delegate = self
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        _viewDidAppear = true
        self.mochiMakeSelectedTabTransparent()
        MochiCrashReporter.presentPendingReportIfNeeded(from: self)
        
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

extension TabBarController: UITabBarControllerDelegate
{
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
    {
        self.mochiMakeSelectedTabTransparent()
    }
}

// MochiLoad: actions coming from the Home tab, and refreshing automatically when the app opens.
extension TabBarController
{
    private static var mochiLastAutoRefresh: Date?
    
    private var mochiMyAppsViewController: MyAppsViewController? {
        guard let tabs = self.viewControllers, tabs.count > Tab.myApps.rawValue,
              let navigationController = tabs[Tab.myApps.rawValue] as? UINavigationController else { return nil }
        return navigationController.viewControllers.first as? MyAppsViewController
    }
    
    @objc func mochiRefreshAllApps(_ notification: Notification)
    {
        guard let myApps = self.mochiMyAppsViewController else { return }
        self.selectedIndex = Tab.myApps.rawValue
        self.mochiMakeSelectedTabTransparent()
        myApps.loadViewIfNeeded()
        DispatchQueue.main.async {
            myApps.mochiStartRefreshAll()
        }
    }
    
    @objc func mochiOpenMyApps(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
        self.mochiMakeSelectedTabTransparent()
    }
    
    @objc func mochiOpenSettings(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
        self.mochiMakeSelectedTabTransparent()
    }
    
    @objc func mochiOpenPairing(_ notification: Notification)
    {
        guard let tabs = self.viewControllers, let home = tabs.first as? UINavigationController else { return }
        self.selectedIndex = Tab.news.rawValue
        let pairing = UIHostingController(rootView: PairingFileManagementView())
        pairing.title = NSLocalizedString("Pair This iPhone", comment: "")
        home.pushViewController(pairing, animated: true)
    }
    
    @objc func mochiAppDidBecomeActive(_ notification: Notification)
    {
        guard MochiAutomation.autoRefreshOnOpen, DatabaseManager.shared.isStarted else { return }
        if let last = Self.mochiLastAutoRefresh, Date().timeIntervalSince(last) < 30 * 60 { return }
        
        let soon = Date().addingTimeInterval(2 * 24 * 60 * 60)
        let needsRefresh = InstalledApp.fetchActiveApps(in: DatabaseManager.shared.viewContext).contains { $0.expirationDate < soon }
        guard needsRefresh, PairingFileManager.shared.fetchPairingFile() != nil else { return }
        
        Self.mochiLastAutoRefresh = Date()
        Task { @MainActor in
            do
            {
                // Only when LocalDevVPN is on; otherwise stay quiet and let Home explain.
                try await ensureMinimuxerReady()
            }
            catch
            {
                debugLog("[MochiLoad] Skipping refresh on open: not connected (\(error))")
                return
            }
            
            guard let myApps = self.mochiMyAppsViewController else { return }
            debugLog("[MochiLoad] Apps expire within 2 days; refreshing automatically.")
            myApps.loadViewIfNeeded()
            myApps.mochiStartRefreshAll()
        }
    }
}
