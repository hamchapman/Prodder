//
//  StatusMenuController.swift
//  Prodder
//
//  Created by Hamilton Chapman on 04/02/2016.
//  Copyright © 2016 hc.gg. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    
    let BROWSERS = ["Firefox", "Safari", "Google Chrome", "Google Chrome Canary"]
    let BASE_ENDPOINT = "https://proddy.herokuapp.com"
    let defaults = NSUserDefaults.standardUserDefaults()
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proddableAppList: NSMenuItem!
    @IBOutlet weak var proddableAppListMenu: NSMenu!
    @IBOutlet weak var currentLeader: NSMenuItem!
    @IBOutlet weak var yourRank: NSMenuItem!

    @IBAction func quitClicked(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    @IBAction func resetUsername(sender: AnyObject) {
        defaults.setObject(nil, forKey: "user_id")
    }
    
    
    override func awakeFromNib() {
        if let button = statusItem.button {
            button.image = NSImage(named: "proddy-logo-black32")
        }
        
        statusItem.menu = statusMenu
        
        checkRunningApplication()
        NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "checkRunningApplication", userInfo: nil, repeats: true)
        
//        initialiseExtremeMode()
    }
    
    func activateExtremeMode(item: NSMenuItem) {
        bringAppToForeground(item.title)
    }
    
    func initialiseExtremeMode() {
//        let pid = app.processIdentifier
        let windowList: CFArrayRef = CGWindowListCopyWindowInfo(CGWindowListOption.OptionAll, CGWindowID(0))!
//        print(windowList)
        
        for win in windowList {
            if let windy = win as? Dictionary<String, AnyObject> {
                print(windy["kCGWindowOwnerPID"])
                print(windy["kCGWindowNumber"])
                print(windy["kCGWindowName"])
                
                if let windowName = windy["kCGWindowName"] as? String {
                    if windowName == "room_channel.ex — hcgg" {
                        if let windowNum = windy["kCGWindowNumber"] as? Int {
                            print(windowNum)
                            let special = NSApp.windowWithWindowNumber(windowNum)
                            print(special)
                            special!.level = Int(CGWindowLevelForKey(.MaximumWindowLevelKey))
//                            special!.level = Int(CGWindowLevelForKey(.FloatingWindowLevelKey))
                        }
                    }
                }
            }
        }
    }
    
    func bringAppToForeground(appName: String) {
        for runningApp in NSWorkspace.sharedWorkspace().runningApplications {
            if let name = runningApp.localizedName where name == appName {
                runningApp.activateWithOptions(NSApplicationActivationOptions.ActivateIgnoringOtherApps)
            }
        }
    }
    
    func checkRunningApplication() {
        
        let newProddableAppListMenu = NSMenu()
        
        for runningApp in NSWorkspace.sharedWorkspace().runningApplications {
            if runningApp.activationPolicy == NSApplicationActivationPolicy.Regular {
                
                let appListItem = NSMenuItem(title: runningApp.localizedName!, action: Selector("activateExtremeMode:"), keyEquivalent: "")
                appListItem.image = runningApp.icon!
                appListItem.target = self
                
                // get screenshots of windows
                
                newProddableAppListMenu.addItem(appListItem)
                
                if let name = runningApp.localizedName where runningApp.active {
                    print("\(runningApp.localizedName!)")

                    var url: String? = nil
                    
                    if BROWSERS.contains(name) {
                        url = getBrowserTabURL(name)
                        print(url)
                    }
                
                    postToVivansMagicalBackend(name, url: url)
                }
            }
        }
        
        statusMenu.setSubmenu(newProddableAppListMenu, forItem: proddableAppList)
    }
    
    func postToVivansMagicalBackend(name: String, url: String? = nil) {
        guard let _ = defaults.stringForKey("user_id") else {
            createUserWithVivansMagicalBackend()
            return
        }
        
        var hostname: String? = nil
        
        if url != nil {
            if let host = NSURL(string: url!)!.host {
                print("is this optional: \(host)")
                hostname = host
            } else {
                hostname = url!
            }
        }
        
        let  URLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let request = NSMutableURLRequest(URL: NSURL(string: "\(BASE_ENDPOINT)/events")!)
        request.HTTPMethod = "POST"
        
        if let h = hostname {
            request.HTTPBody = "app_name=\(name)&hostname=\(h)&user_id=\(defaults.stringForKey("user_id")!)&timestamp=\(NSDate().timeIntervalSince1970)".dataUsingEncoding(NSUTF8StringEncoding)
        } else {
            request.HTTPBody = "app_name=\(name)&user_id=\(defaults.stringForKey("user_id")!)&timestamp=\(NSDate().timeIntervalSince1970)".dataUsingEncoding(NSUTF8StringEncoding)
        }

        let task = URLSession.dataTaskWithRequest(request, completionHandler: { data, response, error in
            if error != nil {
                print("Error \(error)")
            }
            if let httpResponse = response as? NSHTTPURLResponse where (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                do {
                    if let json = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? Dictionary<String, AnyObject> {
                        print(json)
                        if let rank = json["rank"] as? Int, numUsers = json["no_of_users"] as? Int, leader = json["leader"] as? String {
                            if let button = self.statusItem.button {
                                button.image = NSImage(named: "proddy-logo-\(self.getIconColourFromRankAndUsers(rank, numUsers: numUsers))32")
                            }
                            self.currentLeader.title = "Today's leader: \(leader)"
                            self.yourRank.title = "Rank \(rank) out of \(numUsers)"
                        }
                    }
                } catch {
                    print("Error getting event_id")
                }
            } else {
                print("Error from Vivan's backend")
            }
        })
        
        task.resume()
    }
    
    func createUserWithVivansMagicalBackend() {
        let username = NSUserName()
        
        let URLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let request = NSMutableURLRequest(URL: NSURL(string: "\(BASE_ENDPOINT)/users")!)
        request.HTTPMethod = "POST"
        request.HTTPBody = "user_name=\(username)".dataUsingEncoding(NSUTF8StringEncoding)
        
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { data, response, error in
            if error != nil {
                print("Error \(error)")
            }
            
            if let httpResponse = response as? NSHTTPURLResponse where (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                do {
                    if let json = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? Dictionary<String, AnyObject> {
                        print(json)
                        if let userId = json["user_id"] as? String {
                            print(userId)
                            self.defaults.setObject(userId, forKey: "user_id")
                        }
                    }
                } catch {
                    print("Error getting user_id")
                }
            } else {
                print("Error from Vivan's backend")
            }
        })
        
        task.resume()
    }
    
    func getBrowserTabURL(appName: String) -> String? {
        let script = generateScript(appName)
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            if let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error) {
                return output.stringValue
            } else if (error != nil) {
                print("error: \(error)")
            }
        }
        return nil
    }
    
    func generateScript(appName: String) -> String {
        return "set frontApp to \"\(appName)\"\n" +
            "if (frontApp = \"Safari\") or (frontApp = \"Webkit\") then\n" +
            "using terms from application \"Safari\"\n" +
            "tell application frontApp to set currentTabUrl to URL of front document\n" +
            "end using terms from\n" +
            "else if (frontApp = \"Google Chrome\") or (frontApp = \"Google Chrome Canary\") or (frontApp = \"Chromium\") then\n" +
            "using terms from application \"Google Chrome\"\n" +
            "tell application frontApp to set currentTabUrl to URL of active tab of front window\n " +
            "end using terms from\n" +
            "else\n" +
            "return \"You need a supported browser as your frontmost app\"\n" +
            "end if\n" +
            "return currentTabUrl"
    }
    
    func getIconColourFromRankAndUsers(rank: Int, numUsers: Int) -> String {
        let coeff = Double(rank) / Double(numUsers)
        
        if numUsers >= 5 {
            switch coeff {
            case _ where coeff <= 0.2:
                return "green"
            case _ where coeff <= 0.4:
                return "green-yellow"
            case _ where coeff <= 0.6:
                return "orange"
            case _ where coeff <= 0.8:
                return "red-orange"
            default:
                return "red"
            }
        } else if numUsers == 4 {
            switch coeff {
            case _ where coeff <= 0.25:
                return "green"
            case _ where coeff <= 0.5:
                return "green-yellow"
            case _ where coeff <= 0.75:
                return "red-orange"
            default:
                return "red"
            }
        } else if numUsers == 3 {
            switch coeff {
            case _ where coeff <= 0.34:
                return "green"
            case _ where coeff <= 0.67:
                return "orange"
            default:
                return "red"
            }
        } else if numUsers == 2 {
            switch coeff {
            case _ where coeff <= 0.5:
                return "green"
            default:
                return "red"
            }
        } else {
            return "green"
        }
    }
}


extension CFArray: SequenceType {
    public func generate() -> AnyGenerator<AnyObject> {
        var index = -1
        let maxIndex = CFArrayGetCount(self)
        return anyGenerator{
            guard ++index < maxIndex else {
                return nil
            }
            let unmanagedObject: UnsafePointer<Void> = CFArrayGetValueAtIndex(self, index)
            let rec = unsafeBitCast(unmanagedObject, AnyObject.self)
            return rec
        }
    }
}



