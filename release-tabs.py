"""
	Release builder GUI invoker
"""

import subprocess
import sys
import PySimpleGUI as sg
from PySimpleGUI.PySimpleGUI import theme_border_width

font = ('Helvetica',14)

sg.theme('Dark Blue 2')
sg.set_options(font=font)

build_options = ['help', 'release', 'r-mode-3']

icv_layout = [
			  [
				sg.Text('build   '),sg.Input('B0',size=(12,1), key='-IN-'),
			    sg.Text('platform'),sg.Input('EVALUATION_BOARD',
											  size=(22,1), key='-IN-TAB1-')
			  ],
			  [
#			   sg.Checkbox('help',key='opt-help'),
			   sg.Checkbox('docs',   key='-icv-docs-', default=False),
			   sg.Checkbox('boot',   key='-icv-boot-', default=True),
			   sg.Checkbox('burn',   key='-icv-burn-', default=True),
			   sg.Checkbox('prov',   key='-icv-prov-', default=True),
			   sg.Checkbox('time',   key='-icv-time-', default=False),
			   sg.Checkbox('clean',  key='-icv-clean-',default=False),
			   sg.Checkbox('spell',  key='-icv-spell-',default=True),
			   sg.Checkbox('tar',    key='-icv-tar-',  default=False)
			  ],
			  [sg.Checkbox('hexon',  key='-icv-hexon-',default=False),
			   sg.Checkbox('manoff', key='-icv-manoff-',default=False),
			   sg.Checkbox('release',key='opt-release',default=False)
			  ]
			]

oem_layout = [
			  [sg.Text('build'),sg.Input("B0",size=(12,1), key='-IN-')],
			  [
			   sg.Checkbox('executable', key='-oem-exe-',default=False),
			   sg.Checkbox('time',  key='-oem-time-',default=False),
			   sg.Checkbox('spell', key='-oem-spell-',default=True),
			   sg.Checkbox('hexon', key='-oem-hexon-',default=False),
			   sg.Checkbox('tar',   key='-oem-tar-',default=False)
			  ]
			]

srv_layout = [
			  [sg.Text('build'),sg.Input("B0",size=(12,1), key='-IN-')],
			
			  [
#			   sg.Checkbox('help', key='opt-help',default=False),
			   sg.Checkbox('time', key='-srv-time-',default=False),
			   sg.Checkbox('clean',key='-srv-clean-',default=False),
			   sg.Checkbox('tar',  key='-srv-tar-' ,default=False)
			 ]
			]

tab_group_layout = [[sg.Tab('ALIF (ICV)',
						    icv_layout,
						    key='-ICV-',
						    font='Courier 15',
						    border_width=15,
						    tooltip='ICV Release'),
					 sg.Tab('Application (OEM)',
						    oem_layout,key='-OEM-',
						    tooltip='APP release'),
					 sg.Tab('Service (SRV)',
						    srv_layout,
						    key='-SRV-'),
					 sg.Button('Close'),
					 sg.Button('Run')
				   ]]
tab_keys = ('-ICV-', '-OEM-', '-SRV-')

#class icv_options:
#def __init__(self):
#		self.icv-docs=False
#		self.icv-boot=False
#		self.icv-burn=True
#		self.icv-prov=True
#		self.icv-time=False
#		self.icv-clean=False
#		self.icv-spell=True
#		self.icv-tar=False
#		self.icv-hexon=False
#		self.icv-manoff=False
#		self.icv-release=False

def main():
	layout = [
				[sg.Output(size=(80,20), 
						   background_color='black', 
						   text_color='white')],
				[sg.TabGroup(tab_group_layout,
				           enable_events=True,
				           size=(900,146),
				           key='-TABGROUP-')]
             ]
	window = sg.Window("ALIF SE Release Builder", layout, finalize=True,)
	print("about to loop..")
	while True:             # Event Loop
		event, values = window.read()
		print(event)
		print(values)
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
		if event == 'Run':
			runCommand(cmd='bash argc.sh -h', window=window)
		if values['-icv-docs-']:
			print("icv doc ENABLED")
	
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
