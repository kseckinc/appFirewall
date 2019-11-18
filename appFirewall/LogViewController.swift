//
//  LogViewController.swift
//  appFirewall
//


import Cocoa

class LogViewController: NSViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var tableHeaderView: NSTableHeaderView!
	var timer : Timer!
	var asc: Bool = false // whether log is shown in ascending/descending order

	@IBOutlet weak var tableHeader: NSTableHeaderView!

	@IBOutlet weak var ConnsColumn: NSTableColumn!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self

		// schedule refresh of connections list every 1s
		timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
		timer.tolerance = 1 // we don't mind if it runs quite late
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		self.view.window?.setFrameUsingName("connsView") // restore to previous size
		UserDefaults.standard.set(1, forKey: "tab_index") // record active tab
		
		// enable click of column header to call sortDescriptorsDidChange action below
		asc = UserDefaults.standard.bool(forKey: "log_asc")
		if (tableView.tableColumns[0].sortDescriptorPrototype==nil) {
			tableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key:"time",ascending:asc)
			tableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key:"conn",ascending:asc)
		}
		
		ConnsColumn.headerCell.title="Connections ("+String(Int(get_num_conns_blocked()))+" blocked)"
		
		refresh(timer: nil) // refresh the table when it is redisplayed
	}
	
	@objc func refresh(timer:Timer?) {
		//print("log refresh", has_log_changed())
		var force : Bool = true
		if (timer != nil) {
			force = false
		}
		let firstVisibleRow = tableView.rows(in: tableView.visibleRect).location
		//print("log, firstVisibleRow=",firstVisibleRow," NSLoc=",NSLocationInRange(0,tableView.rows(in: tableView.visibleRect))," haschanged=",has_log_changed())
		if (force
			  || (firstVisibleRow==0) // if scrolled down, don't update
						&& (has_log_changed() == 1)) {
			// log is updated by sniffing of new conns
			//print("refresh log")
			clear_log_changed()
			tableView.reloadData()
		} else if (has_log_changed() == 1){
			// update scrollbars but leave rest of view alone
			tableView.noteNumberOfRowsChanged()
		}
		ConnsColumn.headerCell.title="Connections ("+String(Int(get_num_conns_blocked()))+" blocked)"
	}

	override func viewWillDisappear() {
		super.viewWillDisappear()
		//print("saving state")
		save_log()
		save_blocklist(); save_whitelist()
		save_dns_cache()
		self.view.window?.saveFrame(usingName: "connsView") // record size of window
	}
	
	
	@IBAction func helpButton(_ sender: NSButton!) {
			let storyboard = NSStoryboard(name:"Main", bundle:nil)
			let controller : helpViewController = storyboard.instantiateController(withIdentifier: "HelpViewController") as! helpViewController
			
			let popover = NSPopover()
			popover.contentViewController = controller
			popover.contentSize = controller.view.frame.size
			popover.behavior = .transient; popover.animates = true
			popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.minY)
			controller.message(msg:String("This window logs the network connections made by the apps running on your computer.  Connections marked in green are not blocked.  Those marked in red are blocked by the blacklist (on the next tab), those in orange and brown are blocked by filter files (see preferences to modify these)."))
		}
	
	@objc func updateTable (rowView: NSTableRowView, row:Int) -> Void {
		// update all of the buttons in table (called after
		// pressing a button changes blacklist state etc)
		let button = rowView.view(atColumn:2) as! blButton
		let item_ptr = button.item_ptr
		var item = item_ptr!.pointee
		//print(row, String(cString: &item.bl_item.name.0))
		updateButton(cell: button)
	}
	
	@objc func BlockBtnAction(sender : blButton!) {	
		let item_ptr = sender.item_ptr
		var item = item_ptr!.pointee
		let name = String(cString: &item.bl_item.name.0)
		var bl_item = item.bl_item
		let domain = String(cString: &bl_item.domain.0)
		if ((name.count==0) || name.contains("<unknown>") ) {
			print("Tried to block item with process name <unknown> or ''")
			return // PID name is missing, we can't add this to block list
		}
		var white: Int = 0
		if (in_whitelist_htab(&bl_item, 0) != nil) {
			white = 1
		}
		var blocked: Int = 0
		if (in_blocklist_htab(&bl_item, 0) != nil) {
			blocked = 1
		} else if (in_hostlist_htab(domain) != nil) {
			blocked = 2
		} else if (in_blocklists_htab(&bl_item) != nil) {
			blocked = 3
		}
		
		if (sender.title.contains("Allow")) {
			if (blocked == 1) { // on block list, remove
				del_blockitem(&bl_item)
			} else if (blocked>1) { // on host list, add to whitelist
				add_whiteitem(&bl_item)
			}
		} else { // block
			if (white == 1) { // on white list, remove
				del_whiteitem(&bl_item)
			}
			if (blocked == 0) {
				add_blockitem(&bl_item)
			}
		}
		// update (without scrolling)...
		tableView.enumerateAvailableRowViews(updateTable)
		}
}

extension LogViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return Int(get_log_size());
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		guard let sortDescriptor = tableView.sortDescriptors.first else {
    return }
    asc = sortDescriptor.ascending
		UserDefaults.standard.set(asc, forKey: "log_asc")
		if (asc != oldDescriptors.first?.ascending) {
			tableView.reloadData()
		}
	}
}

extension LogViewController: NSTableViewDelegate {
	
	func mapRow(row: Int) -> Int {
		//map from displayed row to row in log itself
		let log_last = Int(get_log_size())-1
		if (row<0) { return 0 }
		if (row>log_last) { return log_last }
		if (asc) {
			return row
		} else {
			return log_last-row
		}
	}
	
	func invMapRow(r: Int) -> Int {
		//map from row in log to displayed row
		let log_last = Int(get_log_size())-1
		if (r<0) { return 0 }
		if (r>log_last) { return log_last }
		if (asc) {
			return r
		} else {
			return log_last-r
		}
	}
	
	func getRowText(row: Int) -> String {
		let r = mapRow(row: row)
		let item_ptr = get_log_row(Int32(r))
		var item = item_ptr!.pointee
		let time_str = String(cString: &item.time_str.0)
		let log_line = String(cString: &item.log_line.0)
		return time_str+" "+log_line
	}
	
	func updateButton(cell: blButton) {
		// refresh the contents based on current data
		var item = cell.item_ptr!.pointee
		var white: Int = 0
		if (in_whitelist_htab(&item.bl_item, 0) != nil) {
			white = 1
		}
		var blocked: Int = 0
		let domain = String(cString: &item.bl_item.domain.0)
		if (in_blocklist_htab(&item.bl_item, 0) != nil) {
			blocked = 1
		} else if (in_hostlist_htab(domain) != nil) {
			blocked = 2
		} else if (in_blocklists_htab(&item.bl_item) != nil) {
			blocked = 3
		}
		
		let log_line = String(cString: &item.log_line.0)
		let udp : Bool = log_line.contains("QUIC")
		
		if (udp) { // QUIC, can't block yet
			cell.title = ""
			cell.isEnabled = false
			return
		}
		if (blocked > 1) {
			if (white == 1) {
				cell.title = "Block"
				cell.toolTip = "Remove from white list"
			} else {
				cell.title = "Allow"
				cell.toolTip = "Add to white list"
			}
		} else if (blocked==1) {
			if (white==1) {
				cell.title = "Block"
				cell.toolTip = "Remove from white list"
			} else {
				cell.title = "Allow"
				cell.toolTip = "Remove from black list"
			}
		} else {
			if (white==1) {
				cell.title = "Remove"
				cell.toolTip = "Remove from white list"
			} else {
				cell.title = "Block"
				cell.toolTip = "Add to black list"
			}
		}
		cell.isEnabled = true
		cell.action = #selector(BlockBtnAction)
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		var cellIdentifier: String = ""
		var content: String = ""
		var tip: String = ""
		
		// we display log in reverse order, i.e. youngest first
		//let log_last = Int(get_log_size())-1
		//if (row>log_last) { return nil	}
		let r = mapRow(row: row)
		let item_ptr = get_log_row(Int32(r))
		var item = item_ptr!.pointee
		let time_str = String(cString: &item.time_str.0)
		let log_line = String(cString: &item.log_line.0)
		let blocked_log = Int(item.blocked)

		if tableColumn == tableView.tableColumns[0] {
			cellIdentifier = "TimeCell"
			content=time_str
		} else if tableColumn == tableView.tableColumns[1] {
			cellIdentifier = "ConnCell"
			content=log_line
			let buf = UnsafeMutablePointer<Int8>.allocate(capacity:Int(INET6_ADDRSTRLEN))
			get_log_addr_name(Int32(r), buf, INET6_ADDRSTRLEN)
			let ip = String(cString: buf)
			var domain = String(cString: &item.bl_item.domain.0)
			if (domain.count == 0) {
				domain = ip
			}
			let name = String(cString: &item.bl_item.name.0)
			let port = String(Int(item.raw.dport))
			if (blocked_log == 0) {
				tip = "This connection to "+domain+" ("+ip+":"+port+") was not blocked."
			} else if (blocked_log == 1) {
				tip = "This connection to "+domain+" ("+ip+":"+port+") was blocked for application '"+name+"' by user black list."
			} else if (blocked_log == 2) {
				tip = "This connection to "+domain+" ("+ip+":"+port+") was blocked for all applications by hosts file."
			} else {
				tip = "This connection to "+domain+" ("+ip+":"+port+") was blocked for application '"+name+"' by hosts file."
			}			
		} else {
			cellIdentifier = "ButtonCell"
		}
		
		let cellId = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
		if (cellIdentifier == "ButtonCell") {
			guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) as? blButton else {return nil}
			
			// maintain state for button
			cell.item_ptr = item_ptr
			updateButton(cell: cell)
			return cell
		}
		guard let cell = tableView.makeView(withIdentifier: cellId, owner: self) 	as? NSTableCellView else {return nil}
		cell.textField?.stringValue = content
		cell.textField?.toolTip = tip
		if (blocked_log==1) {// blocked from blocklist
			cell.textField?.textColor = NSColor.red
		} else if (blocked_log==2) { // blocked from hosts list
			cell.textField?.textColor = NSColor.orange
		} else if ( (Int(item.raw.udp)==0) && (blocked_log==3) ) { // blocked from blocklists file list
			cell.textField?.textColor = NSColor.brown
		} else { // not blocked
			cell.textField?.textColor = NSColor.systemGreen
		}
		return cell
	}
	
	func copy(sender: AnyObject?){
		//print("copy Log")
		//var textToDisplayInPasteboard = ""
		let indexSet = tableView.selectedRowIndexes
		var text = ""
		for row in indexSet {
			text += getRowText(row: row)+"\n"
		}
		let pasteBoard = NSPasteboard.general
		pasteBoard.clearContents()
		pasteBoard.setString(text, forType:NSPasteboard.PasteboardType.string)
	}
	
	func selectall(sender: AnyObject?){
		tableView.selectAll(nil)
	}
	
}
