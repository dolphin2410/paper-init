plugins {
    idea
    kotlin("jvm") version Dependency.Kotlin.Version
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

repositories {
    mavenCentral()
    maven("https://papermc.io/repo/repository/maven-public/")
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation(kotlin("reflect"))
    compileOnly("io.papermc.paper:paper-api:${Dependency.Paper.Version}-R0.1-SNAPSHOT")

    Dependency.Libraries.libraries.forEach { library ->
        compileOnly("${library.group}:${library.api}:${library.version}")
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
    ) = register<Copy>("build${classifier.capitalize()}Jar") {
        val prefix = project.name
        val plugins = rootProject.file(".server/plugins")
        val update = File(plugins, "update")
        val regex = Regex("($prefix).*(.jar)")

        from(source)
        into(if (plugins.listFiles { _, it -> it.matches(regex) }?.isNotEmpty() == true) update else plugins)

        rootProject.file("src/main/resources/plugin.yml").writeText("""
            |name: ${rootProject.pluginName}
            |version: ${PluginData.Version}
            |main: io.github.dytroc.${rootProject.packageName}.${rootProject.pluginName}Plugin
            |api-version: ${Dependency.Paper.Version.split(".").take(2).joinToString(".")}
            |libraries:
            ${Dependency.Libraries.libraries.joinToString("\n") { library -> "|  - ${library.group}:${library.api}:${library.version}" }}
        """.trimMargin())


        doLast {
            update.mkdirs()
            File(update, "RELOAD").delete()
        }
    }

    registerJar("dev", jar)
}

idea {
    module {
        excludeDirs.add(file(".server"))
    }
}