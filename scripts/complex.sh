#!/usr/bin/env bash

root_project_name=$1

rm -dr src

cat << EOF > settings.gradle.kts
val prefix = "$root_project_name"
rootProject.name = prefix

include("\${prefix}-plugin", "\${prefix}-api", "\${prefix}-core")
EOF

cat << EOF > build.gradle.kts
plugins {
    idea
    kotlin("jvm") version Dependency.Kotlin.Version
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

allprojects {
    repositories {
        mavenCentral()
    }
}

subprojects {
    apply(plugin = "org.jetbrains.kotlin.jvm")

    repositories {
        maven("https://papermc.io/repo/repository/maven-public/")
    }

    dependencies {
        implementation(kotlin("stdlib"))
        implementation(kotlin("reflect"))
        compileOnly("io.papermc.paper:paper-api:\${Dependency.Paper.Version}-R0.1-SNAPSHOT")

        Dependency.Libraries.libraries.forEach { library ->
            compileOnly("\${library.group}:\${library.core}:\${library.version}")
        }
    }
}

idea {
    module {
        excludeDirs.add(file(".server"))
        excludeDirs.addAll(allprojects.map { it.buildDir })
        excludeDirs.addAll(allprojects.map { it.file(".gradle") })
    }
}
EOF

plugin_file_name=""
package_file_name="${root_project_name/-/}"
IFS=-
for part in $root_project_name; do
  plugin_file_name="$plugin_file_name${part^}"
done

cat << EOF > buildSrc/src/main/kotlin/Project.kt
import org.gradle.api.Project
import org.gradle.jvm.tasks.Jar

private fun Project.subproject(name: String) = project(":\${rootProject.name}-\$name")

val Project.pluginName
    get() = rootProject.name.split("-").joinToString("") { it.capitalize() }
val Project.packageName
    get() = rootProject.name.replace("-", "")


val Project.projectApi
    get() = subproject("api")

val Project.projectCore
    get() = subproject("core")

val Project.projectPlugin
    get() = subproject("plugin")

private fun Project.coreTask(name: String) = projectCore.tasks.named(name, Jar::class.java)

val Project.coreDevJar
    get() = coreTask("coreDevJar")
EOF

mkdir -p "${root_project_name}-plugin/src/main/kotlin/io/github/dytroc/$package_file_name"
mkdir -p "${root_project_name}-plugin/src/main/resources"

cat << EOF > "${root_project_name}-plugin/build.gradle.kts"
dependencies {
    implementation(projectApi)
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
        bundleProject: Project? = null,
        bundleTask: TaskProvider<org.gradle.jvm.tasks.Jar>? = null
    ) = register<Jar>("\${classifier}Jar") {
        archiveBaseName.set(rootProject.name)
        archiveClassifier.set(classifier)

        from(sourceSets["main"].output)

        if (bundleProject != null) from(bundleProject.sourceSets["main"].output)

        bundleTask?.let { bundleJar ->
            dependsOn(bundleJar)
            from(zipTree(bundleJar.get().archiveFile))
        }

        project.file("src/main/resources/plugin.yml").writeText("""
            |name: \${rootProject.pluginName}
            |version: \${PluginData.Version}
            |main: io.github.dytroc.\${rootProject.packageName}.\${rootProject.pluginName}Plugin
            |api-version: \${Dependency.Paper.Version.split(".").take(2).joinToString(".")}
            |libraries:
            \${Dependency.Libraries.libraries.joinToString("\n") { library -> "|  - \${library.group}:\${library.api}:\${library.version}" }}
            \${if (bundleTask == null) "|  - io.github.dytroc:\${rootProject.packageName}-core:\${PluginData.Version}" else "|"}
        """.trimMargin())
    }.also { jar ->
        register<Copy>("build\${classifier.capitalize()}Jar") {
            val prefix = rootProject.name
            val plugins = rootProject.file(".server/plugins")
            val update = File(plugins, "update")
            val regex = Regex("(\$prefix).*(.jar)")

            from(jar)
            into(if (plugins.listFiles { _, it -> it.matches(regex) }?.isNotEmpty() == true) update else plugins)

            doLast {
                update.mkdirs()
                File(update, "RELOAD").delete()
            }
        }
    }

    registerJar("dev", projectApi, coreDevJar)
    registerJar("clip")
}
EOF

cat << EOF > "${root_project_name}-plugin/src/main/kotlin/io/github/dytroc/$package_file_name/${plugin_file_name}Plugin.kt"
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

mkdir -p "${root_project_name}-core/src/main/kotlin/io/github/dytroc/$package_file_name/internal"

cat << EOF > "${root_project_name}-core/build.gradle.kts"
dependencies {
    api(projectApi)
}

tasks {
    jar {
        archiveClassifier.set("origin")
    }

    register<Jar>("coreDevJar") {
        from(sourceSets["main"].output)
    }
}
EOF

cat << EOF > "${root_project_name}-core/src/main/kotlin/io/github/dytroc/$package_file_name/internal/SampleImpl.kt"
package io.github.dytroc.${package_file_name}.internal

import io.github.dytroc.${package_file_name}.Sample

class SampleImpl : Sample
EOF

mkdir -p "${root_project_name}-api/src/main/kotlin/io/github/dytroc/$package_file_name"

cat << EOF > "${root_project_name}-api/src/main/kotlin/io/github/dytroc/$package_file_name/Sample.kt"
package io.github.dytroc.${package_file_name}

interface Sample {
    companion object: Sample by LibraryLoader.loadImplement(Sample::class.java)
}
EOF

cat << EOF > "${root_project_name}-api/src/main/kotlin/io/github/dytroc/$package_file_name/LibraryLoader.kt"
package io.github.dytroc.${package_file_name}

import java.lang.reflect.InvocationTargetException

// Copied from https://github.com/monun/paper-sample-complex/blob/master/sample-api/src/main/kotlin/io/github/monun/sample/LibraryLoader.kt
object LibraryLoader {
    @Suppress("UNCHECKED_CAST")
    fun <T> loadImplement(type: Class<T>, vararg initArgs: Any? = emptyArray()): T {
        val packageName = type.\`package\`.name
        val className = "$\{type.simpleName}Impl"
        val parameterTypes = initArgs.map { it?.javaClass }.toTypedArray()

        return try {
            val internalClass =
                Class.forName("\$packageName.internal.\$className", true, type.classLoader).asSubclass(type)

            val constructor = kotlin.runCatching {
                internalClass.getConstructor(*parameterTypes)
            }.getOrNull() ?: throw UnsupportedOperationException("\${type.name} does not have Constructor for [\${parameterTypes.joinToString()}]")
            constructor.newInstance(*initArgs) as T
        } catch (exception: ClassNotFoundException) {
            throw UnsupportedOperationException("\${type.name} a does not have implement", exception)
        } catch (exception: IllegalAccessException) {
            throw UnsupportedOperationException("\${type.name} constructor is not visible")
        } catch (exception: InstantiationException) {
            throw UnsupportedOperationException("\${type.name} is abstract class")
        } catch (exception: InvocationTargetException) {
            throw UnsupportedOperationException(
                "\${type.name} has an error occurred while creating the instance",
                exception
            )
        }
    }
}
EOF