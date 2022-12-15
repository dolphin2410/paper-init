#!/usr/bin/env bash

root_project_name=$1

cat << EOF > settings.gradle.kts
rootProject.name = "$root_project_name"
EOF

plugin_file_name=""
package_file_name="${root_project_name/-/}"
IFS=-
for part in $root_project_name; do
  plugin_file_name="$plugin_file_name${part^}"
done

mkdir -p src/main/kotlin/io/github/dytroc/$package_file_name

cat << EOF > src/main/kotlin/io/github/dytroc/$package_file_name/${plugin_file_name}Plugin.kt
package io.github.dytroc.${package_file_name}

import org.bukkit.plugin.java.JavaPlugin

class ${plugin_file_name}Plugin : JavaPlugin() {
  companion object {
    lateinit var instance: ${plugin_file_name}Plugin
  }

  override fun onEnable() {
    instance = this
  }
}
EOF