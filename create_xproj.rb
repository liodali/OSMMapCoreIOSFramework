require 'xcodeproj'

project_name = 'OSMFlutterFramework'  # Replace with your project name
project_path = '.'  # Replace with your desired project path

# Create a new Xcode project
project = Xcodeproj::Project.new(project_path + "/#{project_name}.xcodeproj")

# Add a main target
target = project.new_target(:application, project_name, :ios)
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "hamza.dali.${PROJECT_NAME:rfc1034identifier}"
end

# Save the Xcode project
project.save
