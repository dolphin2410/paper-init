import org.gradle.api.Project

val Project.pluginName
    get() = rootProject.name.split("-").joinToString("") { it.capitalize() }
val Project.packageName
    get() = rootProject.name.replace("-", "")