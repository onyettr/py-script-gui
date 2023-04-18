"""
	Release builder GUI invoker
"""

import subprocess
import sys
import PySimpleGUI as sg
from PySimpleGUI.PySimpleGUI import theme_border_width

sg.theme('Dark Blue 3')

build_options = ['help', 'release', 'r-mode-3']

icv_layout = [[sg.Text("icv-release")],
			  [sg.Text('build'),sg.Input(size=(12,1), key='-IN-')],
			  [sg.Text('platform'),sg.Input(size=(12,1), key='-IN-TAB1-')],
			  [sg.Checkbox('help',  key='opt-help')],
			  [sg.Checkbox('docs',  key='opt-docs')],
			  [sg.Checkbox('boot',  key='opt-boot',default=True)],
			  [sg.Checkbox('burn',  key='opt-burn',default=True)],
			  [sg.Checkbox('prov',  key='opt-prov',default=True)],
			  [sg.Checkbox('time',  key='opt-time')],
			  [sg.Checkbox('clean', key='opt-clean')],
			  [sg.Checkbox('spell', key='opt-spell',default=True)],
			  [sg.Checkbox('hexon', key='opt-hexon')],
			  [sg.Checkbox('manoff',key='opt-manoff')],
			  [sg.Checkbox('release',key='opt-release')],
			  [sg.Checkbox('tar', key='opt-tar' )],
			]

oem_layout = [[sg.Text('Application Release')],
			  [sg.Text('build'),sg.Input(size=(12,1), key='-IN-')],
			  [sg.Checkbox('executable', key='opt-exe')],
			  [sg.Checkbox('time',  key='opt-time')],
			  [sg.Checkbox('spell', key='opt-spell',default=True)],
			  [sg.Checkbox('hexon', key='opt-hexon')],
			  [sg.Checkbox('tar',   key='opt-tar' )],
			]

srv_layout = [[sg.Text('Services')],
			  [sg.Text('build'),sg.Input(size=(12,1), key='-IN-')],
			  [sg.Checkbox('help', key='opt-help',default=False)],
			  [sg.Checkbox('time', key='opt-time',default=False)],
			  [sg.Checkbox('clean',key='opt-clean',default=False)],
			  [sg.Checkbox('tar',  key='opt-tar' ,default=False)],
			]

tab_group_layout = [[sg.Tab('ALIF (ICV)',icv_layout,
						    key='-ICV-',
						    font='Courier 15',
						    border_width=15,
						    tooltip='ICV Release'),
					 sg.Tab('Application (OEM)',oem_layout,key='-OEM-',
						    tooltip='APP release'),
					 sg.Tab('Service (SRV)',srv_layout,key='-SRV-'),
					 sg.Button('Close')
				   ]]
tab_keys = ('-ICV-', '-OEM-', '-SRV-')

def main():
	layout = [[sg.TabGroup(tab_group_layout,
				           enable_events=True,
				           size=(400,500),
				           key='-TABGROUP-')]]
	window = sg.Window("ALIF SE Release Builder", layout, finalize=True,)

	while True:             # Event Loop
		event, values = window.read()
		# print(event, values)
		if event in (sg.WIN_CLOSED, 'Exit', 'Close'):
			break
		if event == 'Close':
			break
		if event == 'Visible':
			 window[tab_keys[int(values['-IN-'])-1]].update(visible=False)
		if event == 'Invisible':
			 window[tab_keys[int(values['-IN-'])-1]].update(visible=True)
		if event == 'Select':
			 window[tab_keys[int(values['-IN-'])-1]].select()
		if event == 'Disable':
			 window[tab_keys[int(values['-IN-'])-1]].update(disabled=True)
#		elif event == 'Run':
#			runCommand(cmd=values['-IN-'], window=window)
#			runCommand(cmd='/usr/bin/bash argc.sh -h', window=window)
	window.close()

def runCommand(cmd, timeout=None, window=None):
	nop = None
	""" run shell command
	@param cmd: command to execute
	@param timeout: timeout for command execution
	@param window: the PySimpleGUI window that the output is going to (needed to do refresh on)
	@return: (return code from command, command output)
	"""
	p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	output = ''
	for line in p.stdout:
		line = line.decode(errors='replace' if (sys.version_info) < (3, 5) else 'backslashreplace').rstrip()
		output += line
		print(line)
		window.refresh() if window else nop        # yes, a 1-line if, so shoot me

	retval = p.wait(timeout)

	return (retval, output)

if __name__ == '__main__':
	main()
