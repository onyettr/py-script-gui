"""
	Release builder GUI invoker
"""

import subprocess
import sys
import logging
import PySimpleGUI as sg
from PySimpleGUI.PySimpleGUI import theme_border_width

font = ('Helvetica',14)

sg.theme('Dark Blue 2')
sg.set_options(font=font)
#sg.show_debugger_window(location=(10,10))

build_options = ['help', 'release', 'r-mode-3']

icv_layout = [
			  [
				sg.Text('build   '),
				sg.Input("B0",size=(12,1), key='-icv-build-',
						enable_events=True),
			    sg.Text('platform'),
			    sg.Input("EVALUATION_BOARD",size=(22,1), key='-icv-platform-')
			  ],
			  [
				sg.Checkbox('clean',  key='-icv-clean-',default=False),
				sg.Checkbox('docs',   key='-icv-docs-', default=False),
				sg.Checkbox('boot',   key='-icv-boot-', default=True),
				sg.Checkbox('burn',   key='-icv-burn-', default=True),
				sg.Checkbox('prov',   key='-icv-prov-', default=True),
				sg.Checkbox('time',   key='-icv-time-', default=False),
				sg.Checkbox('spell',  key='-icv-spell-',default=True),
				sg.Checkbox('tar',    key='-icv-tar-',  default=False),
				sg.Checkbox('hexon',  key='-icv-hexon-',default=False),
				sg.Checkbox('manoff', key='-icv-manoff-',default=False),
				sg.Checkbox('suppress',key='-icv-suppress-',default=False),
			  ],
			  [
				sg.Checkbox('release',key='-icv-release-',default=False),
				sg.Checkbox('version',key='-icv-version-',default=False)
			  ]
			]

oem_layout = [
			  [
				sg.Text('build'),
				sg.Input("",size=(12,1), key='-oem-build-',
						enable_events=True)
			  ],
			  [
			   sg.Checkbox('boot', key='-oem-bootc-',default=True),
			   sg.Checkbox('provision', key='-oem-prov-',default=False),
			   sg.Checkbox('executable', key='-oem-exec-',default=False),
			   sg.Checkbox('time',  key='-oem-time-',default=False),
			   sg.Checkbox('spell', key='-oem-spell-',default=True),
			   sg.Checkbox('hexon', key='-oem-hexon-',default=False),
			   sg.Checkbox('tar',   key='-oem-tar-',default=False),
			   sg.Checkbox('version',   key='-oem-version-',default=False),
			   sg.Checkbox('suppress', key='-oem-suppress-',default=False),
			  ]
			]

srv_layout = [
			  [
				sg.Text('build'),
				sg.Input("",size=(12,1), key='-srv-build-',
						enable_events=True)
			  ],
			  [
#			   sg.Checkbox('help', key='opt-help',default=False),
			   sg.Checkbox('time', key='-srv-time-',default=False),
			   sg.Checkbox('clean',key='-srv-clean-',default=False),
			   sg.Checkbox('tar',  key='-srv-tar-' ,default=False),
			   sg.Checkbox('version',  key='-srv-version-' ,default=False)
			 ]
			]

test_release_layout = [
			  [
			   sg.Checkbox('time',    key='-test-time-', default=False),
			   sg.Checkbox('clean',   key='-test-clean-',default=False),
			   sg.Checkbox('spell',   key='-test-spell-',default=True),
			   sg.Checkbox('tar',     key='-test-tar-',  default=False),
			   sg.Checkbox('hexon',   key='-test-hexon-',default=False),
			   sg.Checkbox('manoff',  key='-test-manoff-',default=False),
			   sg.Checkbox('version', key='-test-version-',default=False),
			   sg.Checkbox('suppress',key='-test-suppress-',default=False),
			  ]
			]

# TAB menu layout
tab_group_layout = [
					[sg.Tab('ALIF (ICV)',
						    icv_layout,
						    key='-ICV-',
						    border_width=15,
						    tooltip='ICV Release'),
					 sg.Tab('Application (OEM)',
						    oem_layout,
						    key='-OEM-',
						    tooltip='APP release'),
					 sg.Tab('Service (SRV)',
						    srv_layout,
						    key='-SRV-'),
					 sg.Tab('REV_B0 Bringup',
						    test_release_layout,
						    key='-TST-'),
				     ],
					 [
					 sg.Button('Close'),
					 sg.Button('Run')
				     ]
				  ]

# TAB Menu options for each tool
tab_keys = ('-ICV-', '-OEM-', '-SRV-', '-TST-')

# TAB to script mapping
script_dict = {
		'-TST-' : "bash revb0_test_release.sh",
		'-ICV-' : "bash icv-release.sh",
		'-OEM-' : "bash oem-release.sh",
		'-SRV-' : "bash host-services.sh"
		}

def remove_control_characters(str):
    return rx.sub(r'\p{C}', '', 'my-string')

def determine_tab(tab_selection, tab_options):
	"""
		see which TAB is selected - this could be done better
	"""
	tab_key = "-TABGROUP-"
	which_script = ""
	if tab_key in tab_options:
 		tool = tab_options.get(tab_key)
 		which_script = script_dict.get(tool)

	return which_script

def get_test_options(tst_options):
	"""
		TST TAB selected - extract the options
	"""
	args = ''
#	print(type(tst_options))
#	print("TST Options= ", tst_options)

	if tst_options['-test-time-']:
		args += ' -ts'
	if tst_options['-test-clean-']:
		args += ' -cl'
	if tst_options['-test-spell-']:
		args += ' -c'
	if tst_options['-test-tar-']:
		args += ' -t'
	if tst_options['-test-manoff-']:
		args += ' -mo'
	if tst_options['-test-version-']:
		args += ' -v'
	if tst_options['-test-hexon-']:
		args += ' -hx'
	if tst_options['-test-suppress-']:
		args += ' -zb'
	if tst_options['-test-version-']:
		args += ' -v'

	return args

def get_srv_options(srv_options):
	"""
		SRV TAB selected - extract the options
	"""
	args = ''
#	print(srv_options))

	if srv_options['-srv-build-'] != "":
		args += ' -b ' + srv_options['-srv-build-']
	if srv_options['-srv-time-']:
		args += ' -ts'
	if srv_options['-srv-clean-']:
		args += ' -cl'
	if srv_options['-srv-tar-']:
		args += ' -t'
	if srv_options['-srv-version-']:
		args += ' -v'

	return args

def get_oem_options(oem_options):
	"""
		OEM TAB selected - extract the options
	"""
	args = ''

	if oem_options['-oem-build-'] != "":
		args += ' -b ' + oem_options['-oem-build-']
	if oem_options['-oem-prov-']:
		args += ' -pr'
	if oem_options['-oem-exec-']:
		args += ' -e'
	if oem_options['-oem-time-']:
		args += ' -ts'
	if oem_options['-oem-spell-']:
		args += ' -c'
	if oem_options['-oem-hexon-']:
		args += ' -hx'
	if oem_options['-oem-tar-']:
		args += ' -t'
	if oem_options['-oem-version-']:
		args += ' -v'
	if oem_options['-oem-suppress-']:
		args += ' -zb'

	return args

def get_icv_options(icv_options):
	"""
		ICV TAB selected - extract the options
	"""
	args = ''
#	print(type(icv_options))
#	print("icv-options ", icv_options)

	if icv_options['-icv-build-'] != "":
		args += ' -b ' + icv_options['-icv-build-']
	if icv_options['-icv-platform-'] != "":
		args += ' -p ' + icv_options['-icv-platform-']
	if icv_options['-icv-boot-']:
		args += ' -bs'
	if icv_options['-icv-docs-']:
		args += ' d'
	if icv_options['-icv-clean-']:
		args += ' -cl'
	if icv_options['-icv-burn-']:
		args += ' -bu'
	if icv_options['-icv-prov-']:
		args += ' -pr'
	if icv_options['-icv-tar-']:
		args += ' -t'
	if icv_options['-icv-time-']:
		args += ' -ts'
	if icv_options['-icv-spell-']:
		args += ' -c'
	if icv_options['-icv-release-']:
		args += ' -r'
	if icv_options['-icv-manoff-']:
		args += ' -mo'
	if icv_options['-icv-hexon-']:
		args += ' -hx'
	if icv_options['-icv-suppress-']:
		args += ' -zb'
	if icv_options['-icv-version-']:
		args += ' -v'

	return args

valid_tabs = ["-TST-", "-ICV-", "-SRV-",  "-OEM-"]

def processs_and_execute(values,window):
	"""
		Take the optins and EXEcute them
	"""
	which_tab = values['-TABGROUP-']
	print("[DBG] Which Tab: ", which_tab)

	if which_tab in valid_tabs:
		run_script = script_dict.get(which_tab)
		if which_tab == "-TST-":
			cmd_args = get_test_options(values)
		elif which_tab == "-ICV-":
			cmd_args = get_icv_options(values)
		elif which_tab == "-SRV-":
			cmd_args = get_srv_options(values)
		elif which_tab == "-OEM-":
			cmd_args = get_oem_options(values)
		else:
			print("[ERROR] Unkown TAB")
			print("[DBG] EXE string=", (run_script+cmd_args))
		runCommand(cmd=run_script + cmd_args, window=window)

def main():
	layout = [
				[sg.Output(size=(80,20), 
						   background_color='black', 
						   text_color='white')],
				[sg.TabGroup(tab_group_layout,
				           size=(900,146),
				           key='-TABGROUP-')
				]
             ]
	window = sg.Window("ALIF SE Release Builder", 
					    layout, 
						finalize=True)
#						icon="alif-logo.ico").read(close=True)
	print("[DBG] about to loop..")
	try:
		while True:             # Event Loop
			event, values = window.read()
			cmd_args = " "
			print("[DBG] Event = ", event)
#			print("Values=", values)

			if event in (sg.WIN_CLOSED, 'Exit', 'Close'):
				break
			if event == 'Close':
				break
			if event == '-TABGROUP-':
				run_script = determine_tab(event,values)
				print("[DBG] Which group ", values[event])
				print("[DBG] runscript   ", run_script)
			if event == 'Run':
				processs_and_execute(values,window)
			else:
				print("[ERROR] Invalid TAB")
	except Exception as e:
		sg.Print('Exception in my event loop for the program:', 
				sg.__file__, e, 
				keep_on_top=True, wait=True)
		sg.popup_error_with_traceback('Problem in my event loop!', e)

	window.close()

def execute_command_blocking(command, *args):
    expanded_args = []
    for a in args:
        expanded_args.append(a)
        # expanded_args += a
    print("Running %s %s" %(command, expanded_args))
    try:
        sp = subprocess.Popen([command, expanded_args], shell=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = sp.communicate()
        if out:
            print(out.decode("utf-8"))
        if err:
            print(err.decode("utf-8"))
    except:
        out = ''
    return out
 
def runCommand(cmd, timeout=None, window=None):
	nop = None
	""" run shell command
	@param cmd: command to execute
	@param timeout: timeout for command execution
	@param window: the PySimpleGUI window that the output is going to (needed to do refresh on)
	@return: (return code from command, command output)
	"""
	print("[INFO] Commandline: ", cmd)

	p = subprocess.Popen(cmd, 
						 shell=True, 
						 stdout=subprocess.PIPE, 
						 stderr=subprocess.STDOUT)
	output = ''
	for line in p.stdout:
		line = line.decode(errors='replace' if (sys.version_info) < (3, 5) else 'backslashreplace').rstrip()
#		print("Line ", type(line))
		output += line
		print(line)
		window.refresh() if window else nop        # yes, a 1-line if, so shoot me

	retval = p.wait(timeout)

	return (retval, output)

if __name__ == '__main__':
	logging.basicConfig(level=logging.DEBUG,
                        format='%(message)s',
                        filemode='w')
	logger=logging.getLogger(__name__)

	main()