object Dependency {
    object Kotlin {
        const val Version = "1.7.10"
    }

    object Paper {
        const val Version = "1.19"
    }

    // Libraries
    sealed class Libraries(val group: String, val api: String, val version: String, val core: String = api) {
        companion object {
            const val monun = "io.github.monun"

            val libraries = setOf(Heartbeat, Kommand, Tap)
        }

        object Coroutines : Libraries("org.jetbrains.kotlinx", "kotlinx-coroutines-core", "1.6.4")
        object Heartbeat : Libraries(monun, "heartbeat-coroutines", "0.0.4")
        object Kommand : Libraries(monun, "kommand-api", "2.14.0", "kommand-core")
        object Tap : Libraries(monun, "tap-api", "4.7.1", "tap-core")
    }
}