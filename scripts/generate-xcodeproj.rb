#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates IPWatch.xcodeproj with the menu bar app and the WidgetKit widget
# extension. Re-runnable: it always recreates the project from scratch.
#
# Usage: ruby scripts/generate-xcodeproj.rb

require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'IPWatch.xcodeproj')
APP_DEPLOYMENT = '13.0'
WIDGET_DEPLOYMENT = '14.0'
DEVELOPMENT_TEAM = ENV.fetch('DEVELOPMENT_TEAM', '')

APP_SOURCES = %w[
  IPWatchApp.swift
  AppState.swift
  IPService.swift
  Models.swift
  NetworkMonitor.swift
  SharedStore.swift
  ContentView.swift
].freeze

WIDGET_SHARED_SOURCES = %w[
  IPService.swift
  Models.swift
  NetworkMonitor.swift
  SharedStore.swift
].freeze

WIDGET_SOURCES = %w[
  IPWatchWidgetBundle.swift
  IPWatchWidget.swift
  RefreshIntent.swift
].freeze

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

app = project.new_target(:application, 'IPWatch', :osx, APP_DEPLOYMENT)
widget = project.new_target(:app_extension, 'IPWatchWidget', :osx, WIDGET_DEPLOYMENT)

app_group = project.main_group.new_group('IPWatch', 'Sources/IPWatch')
widget_group = project.main_group.new_group('IPWatchWidget', 'Widget')

APP_SOURCES.each do |file|
  ref = app_group.new_file(file)
  app.source_build_phase.add_file_reference(ref)
end

WIDGET_SHARED_SOURCES.each do |file|
  ref = app_group.new_file(file)
  widget.source_build_phase.add_file_reference(ref)
end

WIDGET_SOURCES.each do |file|
  ref = widget_group.new_file(file)
  widget.source_build_phase.add_file_reference(ref)
end

app.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_NAME'] = 'IPWatch'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.local.ipwatch'
  bs['INFOPLIST_FILE'] = 'Resources/Info.plist'
  bs['MACOSX_DEPLOYMENT_TARGET'] = APP_DEPLOYMENT
  bs['SWIFT_VERSION'] = '5.0'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM unless DEVELOPMENT_TEAM.empty?
  bs['ENABLE_HARDENED_RUNTIME'] = 'YES'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks'
  bs['COMBINE_HIDPI_IMAGES'] = 'YES'
end

widget.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_NAME'] = 'IPWatchWidget'
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.local.ipwatch.widget'
  bs['INFOPLIST_FILE'] = 'Widget/Info.plist'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'Widget/IPWatchWidget.entitlements'
  bs['MACOSX_DEPLOYMENT_TARGET'] = WIDGET_DEPLOYMENT
  bs['SWIFT_VERSION'] = '5.0'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = DEVELOPMENT_TEAM unless DEVELOPMENT_TEAM.empty?
  bs['ENABLE_HARDENED_RUNTIME'] = 'YES'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['SKIP_INSTALL'] = 'YES'
  bs['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../../../../Frameworks'
end

app.add_dependency(widget)

embed_phase = app.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'
build_file = embed_phase.add_file_reference(widget.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(widget)
scheme.set_launch_target(app)
scheme.save_as(PROJECT_PATH, 'IPWatch', true)

puts "Generated #{PROJECT_PATH}"
puts "  targets: IPWatch, IPWatchWidget"
puts "  team: #{DEVELOPMENT_TEAM.empty? ? '(none — set in Xcode)' : DEVELOPMENT_TEAM}"
