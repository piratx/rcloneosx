//
//  processCmd.swift
//  rcloneOSX
//
//  Created by Thomas Evensen on 10.03.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
//  SwiftLint: OK 31 July 2017
//  swiftlint:disable line_length

import Foundation

protocol ErrorOutput: class {
    func erroroutput()
}

enum ProcessTermination {
    case singletask
    case batchtask
    case estimatebatchtask
    case quicktask
    case singlequicktask
    case remoteinfotask
    case automaticbackup
    case rclonesize
    case restore
}

class ProcessCmd: Delay {

    // Number of calculated files to be copied
    var calculatedNumberOfFiles: Int = 0
    // Variable for reference to Process
    var processReference: Process?
    // Message to calling class
    weak var updateDelegate: UpdateProgress?
    // Observer
    weak var notifications: NSObjectProtocol?
    // Command to be executed, normally rclone
    var command: String?
    // Arguments to command
    var arguments: [String]?
    // true if processtermination
    var termination: Bool = false
    // possible error ouput
    weak var possibleerrorDelegate: ErrorOutput?

    func executeProcess (outputprocess: OutputProcess?) {
        // Process
        let task = Process()
        if let command = self.command {
            task.launchPath = command
        } else {
            task.launchPath = Verifyrclonepath().rclonepath()
        }
        task.arguments = self.arguments
        // Pipe for reading output from Process
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let outHandle = pipe.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()
        // Observator for reading data from pipe, observer is removed when Process terminates
        self.notifications = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable,
                            object: nil, queue: nil) { _ in
            let data = outHandle.availableData
            if data.count > 0 {
                if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    outputprocess!.addlinefromoutput(str as String)
                    self.calculatedNumberOfFiles = outputprocess!.count()
                    // Send message about files
                    self.updateDelegate?.fileHandler()
                    if self.termination {
                        self.possibleerrorDelegate?.erroroutput()
                    }
                }
            outHandle.waitForDataInBackgroundAndNotify()
            }
        }
        // Observator Process termination, observer is removed when Process terminates
        self.notifications = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                            object: task, queue: nil) { _ in
            self.delayWithSeconds(0.5) {
                self.termination = true
                self.updateDelegate?.processTermination()
            }
            NotificationCenter.default.removeObserver(self.notifications as Any)
        }
        self.processReference = task
        task.launch()
    }

    // Get the reference to the Process object.
    func getProcess() -> Process? {
        return self.processReference
    }

    // Terminate Process, used when user Aborts task.
    func abortProcess() {
        guard self.processReference != nil else { return }
        self.processReference!.terminate()
    }

    init(command: String?, arguments: [String]?) {
        self.command = command
        self.arguments = arguments
        self.possibleerrorDelegate = ViewControllerReference.shared.getvcref(viewcontroller: .vctabmain) as? ViewControllertabMain
    }
}
