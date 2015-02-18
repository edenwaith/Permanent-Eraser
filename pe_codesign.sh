#!/bin/bash

pe="Permanent Eraser.app"

os_version=`sw_vers -productVersion`
os_version_components=(${os_version//./ })

major_number=os_version_components[0]
minor_number=os_version_components[1]
patch_number=os_version_components[2]

meets_os_requirements=false


if (( major_number >= 10 )); then
	if (( minor_number >= 10 )); then
		# 10.10.0 or later
		meets_os_requirements=true
	elif (( minor_number >= 9 )); then
		if (( patch_number >= 5 )); then
			# 10.9.5 or later
			meets_os_requirements=true
		fi
	fi
fi

if [ "$meets_os_requirements" = false ]; then
	echo "OS X 10.9.5 is required to properly codesign this app."
	exit
fi

if [ -d "$pe" ] 
then
	# Codesign ------------------
	printf "CODESIGNING $pe ------------------ \n"
	codesign --force --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/Library/Automator/Erase.action
	codesign --force --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/Library/Automator/EraseTrash.action

	codesign --force -v --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/PlugIns/Erase.workflow/Contents/document.wflow
	codesign --force -v --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/PlugIns/Erase.workflow/

	codesign --force -v --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/PlugIns/Permanent\ Eraser.workflow/Contents/document.wflow

	codesign --force -v --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app/Contents/PlugIns/Permanent\ Eraser.workflow/

	codesign --force -v --sign "Developer ID Application: Chad Armstrong" Permanent\ Eraser.app

	# Verify ------------------
	printf "\nCODESIGN VERIFICATION ------------------ \n"
	codesign --verify -v Permanent\ Eraser.app 
	spctl -a -t exec -vv Permanent\ Eraser.app
else
	echo "Could not find the app $pe to codesign"
fi