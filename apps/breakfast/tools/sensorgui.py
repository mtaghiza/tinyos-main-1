#!/usr/bin/env python
import pygtk
import gtk
import sys
import gobject

#TODO: structure things like this post-refactor.
def make_menu_item(name, callback, data=None):
	item = gtk.MenuItem(name)
	item.connect("activate", callback, data)
	item.show()
	return item


def make_button(name, callback, data=None):
	item = gtk.Button(name)
	item.connect("clicked", callback, data)
	item.show()
	return item


def make_label(name):
	item = gtk.Label(name)
	item.show()
	return item


def make_window(name, border = 10):
	window = gtk.Window(gtk.WINDOW_TOPLEVEL)
	window.set_title(name)
	window.set_border_width(border)
	window.show()
	return window


def make_table(x, y):
	table = gtk.Table(x, y, False)
	table.show()
	return table


class Sensor:
	def __init__(self):
		self.barcode = ""
		self.sensor_type = None
		self.test_samples = []
		self.barcode_entry = None

	def set_type(self, widget, sensor_type):
		self.sensor_type = sensor_type
	
	def set_barcode_entry(self, entry):
		self.barcode_entry = entry

	def widget_accept_barcode(self, widget, data=None):
		self.accept_barcode()

	def accept_barcode(self):
		if self.barcode_entry.get_text() == "":
			return
		self.barcode = self.barcode_entry.get_text()

class SensorList(list):
	def widget_accept_all_barcodes(self, widget, data=None):
		self.accept_all_barcodes()

	def widget_discard_all_barcodes(self, widget, data=None):
		self.discard_all_barcodes()

	def accept_all_barcodes(self):
		for sensor in self:
			sensor.accept_barcode()

	def discard_all_barcodes(self):
		self = []

#TODO: use these post-refactor
class Toast:
	pass

class Bacon:
	pass

class SensorGui:
	def set_bacon_type(self, widget, bacon_type):
		print bacon_type

	def sublevel_baconconf_gui(self):
		self.sub_window.connect("delete_event", self.sublevel_quit)

		self.sub_table = gtk.Table(1, 2, False)
		self.sub_window.add(self.sub_table)
		self.sub_table.show()

		bacon_sensor_button = gtk.Button("Configure as Sensor")
		bacon_sensor_button.connect("clicked", self.set_bacon_type, "sensor")
		self.sub_table.attach(bacon_sensor_button, 0, 1, 0, 1)
		bacon_sensor_button.show()

		bacon_router_button = gtk.Button("Configure as Router")
		bacon_router_button.connect("clicked", self.set_bacon_type, "router")
		self.sub_table.attach(bacon_router_button, 0, 1, 1, 2)
		bacon_router_button.show()

		bacon_pc_interface_button = gtk.Button("Configure as PC Interface")
		bacon_pc_interface_button.connect("clicked", self.set_bacon_type, "pcinterface")
		self.sub_table.attach(bacon_pc_interface_button, 0, 1, 2, 3)
		bacon_pc_interface_button.show()

		bacon_toast_interface_button = gtk.Button("Configure as toast Interface")
		bacon_toast_interface_button.connect("clicked", self.set_bacon_type, "toastinterface")
		self.sub_table.attach(bacon_toast_interface_button, 0, 1, 3, 4)
		bacon_toast_interface_button.show()



	def set_server_address(self, widget, address_entry):
		print address_entry.get_text()
		return

	def sublevel_settings_gui(self):
		self.sub_window.connect("delete_event", self.sublevel_quit)

		self.sub_table = gtk.Table(3, 1, False)
		self.sub_window.add(self.sub_table)
		self.sub_table.show()

		server_address_label = gtk.Label("Server Address:")
		self.sub_table.attach(server_address_label, 0, 1, 0, 1)
		server_address_label.show()

		server_address = gtk.Entry()
		server_address.set_max_length(50)
		self.sub_table.attach(server_address, 1, 2, 0, 1)
		server_address.show()

		address_button = gtk.Button("Accept Address")
		address_button.connect("clicked", self.set_server_address, server_address)
		self.sub_table.attach(address_button, 2, 3, 0, 1)
		address_button.show()


		

	def sublevel_bacon_gui(self):
		self.sub_window.connect("delete_event", self.sublevel_quit)

		self.sub_table = gtk.Table(2, 4, False)
		self.sub_window.add(self.sub_table)
		self.sub_table.show()

		window_label = gtk.Label("Label Bacon Motes")
		self.sub_table.attach(window_label, 0, 1, 0, 1)
		window_label.show()

		bacon_mac_label = gtk.Label("Manufacturer ID:")
		self.sub_table.attach(bacon_mac_label, 0, 1, 1, 2)
		bacon_mac_label.show()

		self.bacon_mac = gtk.Label("Waiting for ID")
		self.sub_table.attach(self.bacon_mac, 1, 2, 1, 2)
		self.bacon_mac.show()	

		self.bacon_mac_poll_id = gobject.timeout_add(1000, self.timeout_poll_bacon_mac)

		self.bacon_barcode = gtk.Entry()
		self.bacon_barcode.set_max_length(50)
		self.sub_table.attach(self.bacon_barcode, 0, 1, 3, 4)
		self.bacon_barcode.connect("activate", self.logEntry)
		self.bacon_barcode.show()

		barcode_button = gtk.Button("Accept Barcode")
		barcode_button.connect("clicked", self.accept_bacon_barcode)
		self.sub_table.attach(barcode_button, 1, 2, 3, 4)
		barcode_button.show()


	def add_new_sensor(self, widget, Data=None):
		self.sensors.append(Sensor())
		self.sub_table.hide()
		self.sub_window.remove(self.sub_table)
		self.sub_window.hide()
		self.prepare_sublevel()
		self.sublevel_toast_gui()
		self.sub_window.show()

	def remove_sensor(self, widget, sensor):
		self.sensors.remove(sensor)
		self.sub_table.hide()
		self.sub_window.remove(self.sub_table)
		self.sub_window.hide()
		self.prepare_sublevel()
		self.sublevel_toast_gui()
		self.sub_window.show()

	def start_sensor_test(self, widget, sensorlist):
		for sensor in sensorlist:
			if sensor.barcode == "":
				return

	def stop_sensor_test(self, widget, sensorlist):
		for sensor in sensorlist:
			if sensor.barcode == "":
				return

	def clear_sensor_test(self, widget, sensorlist):
		for sensor in sensorlist:
			if sensor.barcode == "":
				return
			sensor.test_samples = []

	def save_sensor_test(self, widget, sensorlist):
		for sensor in sensorlist:
			if sensor.barcode == "":
				return

	def refresh_test_label(self, test_data_label, sensor):
		test_data_label.set_text("# Samples: " + str(len(sensor.test_samples)) + " Mean: " + str(0) + " SD: " + str(0))
		return True

	def event_remove_timeouts(self, widget, event, tags):
		for tag in tags:
			gobject.source_remove(tag)

	def test_sensors(self, widget, sensorlist): #FIXME: this can become a more generalized test_sensors, return to arg style
		if sensorlist == []:
			return

		test_window = gtk.Window(gtk.WINDOW_TOPLEVEL)
		test_window.set_title("LUYF Sensor Configuration Tool (Batch sensor testing)")
		test_window.set_border_width(10)
		test_window.connect("delete_event", self.delete_event)
		test_window.show()

		test_table = gtk.Table(6,1, False)
		test_window.add(test_table)
		test_table.show()

		test_start_button = make_button("Start", self.start_sensor_test, sensorlist)
		test_table.attach(test_start_button, 0, 1, 0, 1)

		test_stop_button = make_button("Stop", self.stop_sensor_test, sensorlist)
		test_table.attach(test_stop_button, 1, 2, 0, 1)

		test_clear_button = make_button("clear", self.clear_sensor_test, sensorlist)
		test_table.attach(test_clear_button, 2, 3, 0, 1)

		test_save_button = make_button("save", self.save_sensor_test, sensorlist)
		test_table.attach(test_save_button, 3, 4, 0, 1)

		test_polls = []
		i = 0
		for sensor in sensorlist:
			sensor_name_label = make_label("Sensor " + str(i+1) + " barcode: ")
			test_table.attach(sensor_name_label, 0, 1, 1 + i, 2 + i)

			sensor_barcode_label = make_label(str(sensor.barcode))
			test_table.attach(sensor_barcode_label, 1, 2, 1 + i, 2 + i)

			test_data_label = make_label("# Samples: " + str(len(sensor.test_samples)) + " Mean: " + str(0) + " SD: " + str(0))
			test_table.attach(test_data_label, 4, 5, 1 + i, 2 + i)

			test_polls.append(gobject.timeout_add(1000, self.refresh_test_label, test_data_label, sensor))
			i += 1

		test_window.connect("delete_event", self.event_remove_timeouts, test_polls)
		test_window.show()


	def prepare_sublevel(self):
		self.toplevel_window.hide()

		self.sub_window = gtk.Window(gtk.WINDOW_TOPLEVEL)
		self.sub_window.set_title("LUYF Sensor Configuration Tool")
		self.sub_window.set_border_width(10)


	def poll_for_toast(self, Data=None):
		self.toast = True #NOTE: populate toast here

	def logEntry(self, widget):
		print "[%s]"%widget.get_text()

	#FIXME: how do we tell if the toast is attached?
	def sublevel_toast_gui(self):
		self.sub_window.connect("delete_event", self.sublevel_cleanup_sensors)

		while len(self.sensors) < 8:
			self.sensors.append(Sensor())

		self.sub_table = gtk.Table(6, 6 + len(self.sensors), False)
		self.sub_window.add(self.sub_table)
		self.sub_table.show()

		pc_mote_label = gtk.Label("PC Interface Mote Status:")
		self.sub_table.attach(pc_mote_label, 0, 1, 0, 1)
		pc_mote_label.show()

		toast_mote_label = gtk.Label("Toast Interface Mote Status:")
		self.sub_table.attach(toast_mote_label, 0, 1, 1, 2)
		toast_mote_label.show()

		separator = gtk.HSeparator()
		self.sub_table.attach(separator, 0, 1, 2, 3)
		separator.show()
		separator = gtk.HSeparator()
		self.sub_table.attach(separator, 1, 2, 2, 3)
		separator.show()
		separator = gtk.HSeparator()
		self.sub_table.attach(separator, 2, 3, 2, 3)
		separator.show()

		self.pc_mote_status = gtk.Label("Waiting for connection")
		self.sub_table.attach(self.pc_mote_status, 2, 3, 0, 1)
		self.pc_mote_status.show()	

		self.toast_mote_status = gtk.Label("Waiting for connection")
		self.sub_table.attach(self.toast_mote_status, 2, 3, 1, 2)
		self.toast_mote_status.show()	

		self.poll_for_toast() #FIXME: change to a "Refresh" button.
		self.toast_poll = gobject.timeout_add(1000, self.poll_for_toast)
		if not self.toast:
			self.sensors = [] #NOTE: only reinitialized here so as to allow someone to go back; configure options; come back and still have sensor lists intact.
			toast_status = gtk.Label("Waiting for Toast Board")
			self.sub_table.attach(toast_status, 1, 2, 3, 4)
			toast_status.show()
			
			return

		toast_barcode_label = gtk.Label("Toast Barcode:")
		self.sub_table.attach(toast_barcode_label, 0, 1, 4, 5)
		toast_barcode_label.show()

		self.toast_barcode = gtk.Entry()
		self.toast_barcode.set_max_length(50)
		self.sub_table.attach(self.toast_barcode, 1, 2, 4, 5)
		self.toast_barcode.show()

		barcode_button = gtk.Button("Accept Barcode")
		barcode_button.connect("clicked", self.accept_toast_barcode)
		self.sub_table.attach(barcode_button, 2, 3, 4, 5)
		barcode_button.show()

		batch_test_button = gtk.Button("Test all sensors")
		batch_test_button.connect("clicked", self.test_sensors, self.sensors)
		self.sub_table.attach(batch_test_button, 4, 5, 5, 6)
		batch_test_button.show()

		new_sensor_button = gtk.Button("New Sensor Entry")
		new_sensor_button.connect("clicked", self.add_new_sensor)
		self.sub_table.attach(new_sensor_button, 0, 1, 5, 6)
		new_sensor_button.show()


		i = 1
		for sensor in self.sensors:
			sensor_label = gtk.Label("Sensor " + str(i) + " Barcode:")
			self.sub_table.attach(sensor_label, 0, 1, 5+i, 6+i)
			sensor_label.show()

			sensor_barcode = gtk.Entry()
			sensor_barcode.set_max_length(50)
			self.sub_table.attach(sensor_barcode, 1, 2, 5+i, 6+i)
			sensor_barcode.set_text(sensor.barcode)
			sensor.set_barcode_entry(sensor_barcode)
			sensor_barcode.connect("activate", self.logEntry)
			sensor_barcode.show()

			sensor_opt_menu = gtk.OptionMenu()
			sensor_menu = gtk.Menu()
			item = make_menu_item("Sensor type A", sensor.set_type, "A")
			sensor_menu.append(item)
			item = make_menu_item("Sensor type B", sensor.set_type, "B")
			sensor_menu.append(item)
			sensor_opt_menu.set_menu(sensor_menu)
			self.sub_table.attach(sensor_opt_menu, 2, 3, 5+i, 6+i)
			sensor_opt_menu.show()

			sensor_barcode_button = gtk.Button("Accept Barcode")
			sensor_barcode_button.connect("clicked", sensor.widget_accept_barcode)
			self.sub_table.attach(sensor_barcode_button, 3, 4, 5+i, 6+i)
			sensor_barcode_button.show()

			sensor_test_button = gtk.Button("Test Sensor")
			sensor_test_button.connect("clicked", self.test_sensors, [sensor])
			self.sub_table.attach(sensor_test_button, 4, 5, 5+i, 6+i)
			sensor_test_button.show()

			sensor_remove_button = gtk.Button("Remove Sensor")
			sensor_remove_button.connect("clicked", self.remove_sensor, sensor)
			self.sub_table.attach(sensor_remove_button, 5, 6, 5+i, 6+i)
			sensor_remove_button.show()

			i += 1

		all_sensor_barcode_button = gtk.Button("Accept All Barcodes")
		all_sensor_barcode_button.connect("clicked", self.sensors.widget_accept_all_barcodes)
		self.sub_table.attach(all_sensor_barcode_button, 3, 4, 6+i, 7+i)
		all_sensor_barcode_button.show()




	#TODO: implement barcode printing/scanning logic
	def accept_bacon_barcode(self, widget, data=None):
		barcode = self.bacon_barcode.get_text()
		mac = self.bacon_mac.get_text()
		if barcode == ""  or mac == "Waiting for ID":
			return

	def accept_toast_barcode(self, widget, data=None):
		barcode = self.toast_barcode.get_text()
		if barcode == "":
			return

	def accept_sensor_barcode(self, widget, sensor=None, sensor_barcode=None):
		if not sensor or not sensor_barcode:
			return
		if sensor_barcode.get_text() == "":
			return
		sensor.barcode = sensor_barcode.get_text()
		

	#TODO: implement mac grabbing logic
	def timeout_poll_bacon_mac(self):
		mac = None
		self.bacon_mac_poll_id = gobject.timeout_add(1000, self.timeout_poll_bacon_mac)
		if mac:
			self.bacon_mac.set_text(str(mac))
		else:
			self.bacon_mac.set_text("Waiting for ID")
		return mac

	def widget_delete_window(self, widget, window):
		window.destroy()


	def widget_sublevel_quit(self, widget, data=None):
		ret = self.sub_window.hide()
		self.toplevel_window.show()


	def sublevel_quit(self, widget, event, data=None):
		self.sub_window.hide()
		self.toplevel_window.show()
		return True


	def sublevel_cleanup_sensors(self, widget, event, data=None):
		for sensor in self.sensors:
			if sensor.barcode == "" and sensor.barcode_entry != None and sensor.barcode_entry.get_text() != "":
				window = make_window("LUYF alert")
				window.connect("delete_event", self.delete_event)

				table = make_table(3, 2)
				window.add(table)

				label = make_label("There are unsaved barcodes.  Would you like to save or discard all?")
				table.attach(label, 1, 2, 0, 1)

				save_button = make_button("Save", self.sensors.widget_accept_all_barcodes) #TODO: connect with other functions to do more stuff.
				save_button.connect("clicked", self.widget_sublevel_quit)
				save_button.connect("clicked", self.widget_delete_window, window)
				table.attach(save_button, 0, 1, 1, 2)
				
				cancel_button = make_button("Cancel", self.widget_delete_window, window)
				table.attach(cancel_button, 1, 2, 1, 2)

				discard_button = make_button("Discard", self.sensors.widget_discard_all_barcodes)
				discard_button.connect("clicked", self.widget_sublevel_quit)
				discard_button.connect("clicked", self.widget_delete_window, window)
				table.attach(discard_button, 2, 3, 1, 2)

				return True

		self.sub_window.hide()
		self.toplevel_window.show()
		return False


	def toplevel_options(self, widget, data):
		self.prepare_sublevel()

		if data == "toast":
			self.sublevel_toast_gui()

		if data == "bacon":
			self.sublevel_bacon_gui()

		if data == "baconconf":
			self.sublevel_baconconf_gui()

		if data == "settings":
			self.sublevel_settings_gui()

		self.sub_window.show()


	def delete_event(self, widget, event, data=None):
#		print "Delete event"
		return False

	def destroy(self, widget, data=None):
#		print "Destroy event"
		gtk.main_quit()

	def main(self):
		gtk.main()

	def __init__(self):
		self.toplevel_window = gtk.Window(gtk.WINDOW_TOPLEVEL)

		self.toplevel_window.set_title("LUYF Sensor Configuration Tool")
		self.toplevel_window.set_border_width(10)
		
		self.toplevel_window.connect("destroy", self.destroy)
		self.toplevel_window.connect("delete_event", self.delete_event)

		self.toplevel_table = gtk.Table(5, 8, False)
		self.toplevel_window.add(self.toplevel_table)

		self.sensors = SensorList() #FIXME: don't like initializing this here; only used inside toast sublevel.

		toast_button = gtk.Button("Label/Assemble Toast Boards")
		toast_button.connect("clicked", self.toplevel_options, "toast")
		self.toplevel_table.attach(toast_button, 0, 1, 1, 2)
		toast_button.show()

		bacon_button = gtk.Button("Label Bacon Mote")
		bacon_button.connect("clicked", self.toplevel_options, "bacon")
		self.toplevel_table.attach(bacon_button, 0, 1, 2, 3)
		bacon_button.show()

		baconconf_button = gtk.Button("Configure Bacon Mote")
		baconconf_button.connect("clicked", self.toplevel_options, "baconconf")
		self.toplevel_table.attach(baconconf_button, 1, 2, 2, 3)
		baconconf_button.show()

		baconconf_button = gtk.Button("Database Settings")
		baconconf_button.connect("clicked", self.toplevel_options, "settings")
		self.toplevel_table.attach(baconconf_button, 1, 2, 0, 1)
		baconconf_button.show()

		self.toplevel_table.show()
		self.toplevel_window.show()


if __name__ == "__main__":
	app = SensorGui()
	exit_status = app.main()
	sys.exit(exit_status)
