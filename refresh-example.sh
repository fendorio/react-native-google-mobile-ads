#!/bin/bash
set -e

echo "You should run this from directory where you have cloned the react-native-google-ads repo"
echo "You should only do this when your git working set is completely clean (e.g., git reset --hard)"
echo "You must have already run \`yarn\` in the repository so \`npx react-native\` will work"
echo "This scaffolding refresh has been tested on macOS, if you use it on linux, it might not work"

# Copy the important files out temporarily
if [ -d TEMP ]; then
  echo "TEMP directory already exists - we use that to store files while refreshing."
  exit 1
else
  echo "Saving files to TEMP while refreshing scaffolding..."
  mkdir TEMP

  # Copy all the config elements
  cp example/metro.config.js TEMP/  # This is customized to handle symbolic links
  cp example/.mocharc.js TEMP/      # Custom mocha settings
  cp example/.detoxrc.json TEMP/    # Custom detox settings
  cp example/app.json TEMP/         # Our custom configuration settings / mobile ads app id etc

  # Our Android DetoxTest integration itself is obviously custom
  mkdir -p TEMP/android/app/src/androidTest/java/com/example
  cp example/android/app/src/androidTest/java/com/example/DetoxTest.java TEMP/android/app/src/androidTest/java/com/example/

  # Our e2e tests themselves are obviously custom
  mkdir -p TEMP/e2e
  cp -r example/e2e/* TEMP/e2e/
fi

# Purge the old sample
\rm -fr example

# Make the new example
npx react-native init example --version=0.66.0
pushd example
yarn add 'link:../'
yarn add detox mocha jest-circus jest-environment-node @babel/preset-env typescript --dev
yarn add 'link:../../jet/'

# Java build tweak - or gradle runs out of memory during the build
echo "Increasing memory available to gradle for android java build"
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" >> android/gradle.properties

# Detox + Android
echo "Integrating Detox for Android (maven repo, dependency, build config items, kotlin...)"
sed -i -e $'s/mavenLocal()/mavenLocal()\\\n        maven \{ url "$rootDir\/..\/node_modules\/detox\/Detox-android" \}/' android/build.gradle
sed -i -e $'s/ext {/ext {\\\n        kotlinVersion = "1.5.30"/' android/build.gradle
sed -i -e $'s/dependencies {/dependencies {\\\n        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion"/' android/build.gradle
rm -f android/build.gradle??
sed -i -e $'s/dependencies {/dependencies {\\\n    androidTestImplementation("com.wix:detox:+")/' android/app/build.gradle
sed -i -e $'s/defaultConfig {/defaultConfig {\\\n        testBuildType System.getProperty("testBuildType", "debug")\\\n        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"/' android/app/build.gradle
rm -f android/app/build.gradle??

# This is just a speed optimization, very optional, but asks xcodebuild to use clang and clang++ without the fully-qualified path
# That means that you can then make a symlink in your path with clang or clang++ and have it use a different binary
# In that way you can install ccache or buildcache and get much faster compiles...
sed -i -e $'s/react_native_post_install(installer)/react_native_post_install(installer)\\\n\\\n    installer.pods_project.targets.each do |target|\\\n      target.build_configurations.each do |config|\\\n        config.build_settings["CC"] = "clang"\\\n        config.build_settings["LD"] = "clang"\\\n        config.build_settings["CXX"] = "clang++"\\\n        config.build_settings["LDPLUSPLUS"] = "clang++"\\\n      end\\\n    end/' ios/Podfile
rm -f ios/Podfile??

# run pod install after installing our module
npx pod-install

# Copy the important files back in
popd
echo "Copying Google Ads example files into refreshed example..."
cp -frv TEMP/.detox* example/
cp -frv TEMP/.mocha* example/
cp -frv TEMP/* example/

# Clean up after ourselves
\rm -fr TEMP