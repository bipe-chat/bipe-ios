#!/bin/bash

# This script is invoked by xcodegen for running post commands

# Move file header template in project shared data folder
cp IDETemplateMacros.plist ../../ElementX.xcodeproj/xcshareddata/

# Bipe: redirect Element's Compound tokens to the açaí fork for every package (compound-ios, element-call-ios)
mkdir -p ../../ElementX.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration
cp mirrors.json ../../ElementX.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/
