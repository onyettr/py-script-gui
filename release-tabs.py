"""
	Release builder GUI invoker
"""

import subprocess
import sys
import PySimpleGUI as sg

sg.theme('Dark Blue 3')

build_options = ['help', 'release', 'r-mode-3']

icv_layout = [[sg.Text("icv-release")],
			  [sg.Radio('help', "opt", key='opt-help')],
			  [sg.Radio('docs', "opt", key='opt-docs')],
			  [sg.Radio('boot', "opt", key='opt-boot')],
			  [sg.Text('build'),sg.Input(size=(12,1), key='-IN-')],
			  [sg.Radio('burn', "opt", key='opt-burn')],
			  [sg.Radio('prov', "opt", key='opt-prov')],
			  [sg.Radio('time', "opt", key='opt-time')],
			  [sg.Radio('clean',"opt", key='opt-clean')],
			  [sg.Radio('spell',"opt", key='opt-spell')],
			  [sg.Radio('hexon',"opt", key='opt-hexon')],
			  [sg.Radio('manoff',"opt", key='opt-manoff')],
			  [sg.Text('platform'),sg.Input(size=(12,1), key='-IN-TAB1-')],
			  [sg.Radio('release',"opt", key='opt-release')],
			  [sg.Radio('tar',  "opt", key='opt-tar' )],
			]
oem_layout = [[sg.Text('oem')]]
srv_layout = [[sg.Text('Services')]]

tab_group_layout = [[sg.Tab('ICV',icv_layout,key='-ICV-'),
					 sg.Tab('OEM',oem_layout,key='-OEM-'),
					 sg.Tab('SRV',srv_layout,key='-SRV-')
				   ]]
tab_keys = ('-ICV-', '-OEM-', '-SRV-')

def main():
	layout1 = [
				[sg.Output(size=(50,30), background_color='black', text_color='white')],
#				[sg.T('Promt> '), sg.Input(key='-IN-', do_not_clear=False)],
                [sg.Radio('help', "opt", key='opt-help'),
				 sg.Radio('clean', "opt", key='opt-clean'),
                 sg.Radio('EXE', "opt", key='opt-exe')
                ],
				[sg.Button('Run', bind_return_key=True), sg.Button('Exit')],
				]
	layout = [[sg.TabGroup(tab_group_layout,
				           enable_events=True,
				           key='-TABGROUP-')]]
	window = sg.Window('ALIF SE Release Builder', layout)

	while True:             # Event Loop
		event, values = window.read()
		# print(event, values)
		if event in (sg.WIN_CLOSED, 'Exit'):
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
