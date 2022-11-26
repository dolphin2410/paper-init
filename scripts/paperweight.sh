#!/usr/bin/env bash

root_project_name=$(basename $(dirname $PWD))
cd ../

cat << EOF > settings.gradle.kts
rootProject.name = "$root_project_name"

pluginManagement {
    repositories {
        gradlePluginPortal()
        maven("https://papermc.io/repo/repository/maven-public/")
    }
}
EOF

cat << EOF > build.gradle.kts
plugins {
    idea
    kotlin("jvm") version Dependency.Kotlin.Version
    id("io.papermc.paperweight.userdev") version "1.3.8"
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation(kotlin("reflect"))
    paperDevBundle("\${Dependency.Paper.Version}-R0.1-SNAPSHOT")

    Dependency.Libraries.libraries.forEach { library ->
        compileOnly("\${library.group}:\${library.core}:\${library.version}")
    }
}

tasks {
    processResources {
        filesMatching("*.yml") {
            expand(project.properties)
            expand(extra.properties)
        }
    }

    fun registerJar(
        classifier: String,
        source: Any
    ) = register<Copy>("build\${classifier.capitalize()}Jar") {
        val prefix = project.name
        val plugins = rootProject.file(".server/plugins")
        val update = File(plugins, "update")
        val regex = Regex("(\$prefix).*(.jar)")

        from(source)
        into(if (plugins.listFiles { _, it -> it.matches(regex) }?.isNotEmpty() == true) update else plugins)

        rootProject.file("src/main/resources/plugin.yml").writeText("""
            |name: \${rootProject.pluginName}
            |version: \${PluginData.Version}
            |main: io.github.dytroc.\${rootProject.packageName}.\${rootProject.pluginName}Plugin
            |api-version: \${Dependency.Paper.Version.split(".").take(2).joinToString(".")}
            |libraries:
            \${Dependency.Libraries.libraries.joinToString("\n") { library -> "|  - \${library.group}:\${library.api}:\${library.version}" }}
        """.trimMargin())


        doLast {
            update.mkdirs()
            File(update, "RELOAD").delete()
        }
    }

    registerJar("reobf", reobfJar)
}

idea {
    module {
        excludeDirs.add(file(".server"))
    }
}
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