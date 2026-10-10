beforeSettings {
    pluginManagement.repositories.clear()
    pluginManagement.repositories.maven { url = uri("http://127.0.0.1:18082/google/"); isAllowInsecureProtocol = true }
    pluginManagement.repositories.maven { url = uri("http://127.0.0.1:18082/gradle/"); isAllowInsecureProtocol = true }
    pluginManagement.repositories.maven { url = uri("http://127.0.0.1:18082/maven/"); isAllowInsecureProtocol = true }
}

settingsEvaluated {
    dependencyResolutionManagement.repositories.clear()
    dependencyResolutionManagement.repositories.maven { url = uri("http://127.0.0.1:18082/google/"); isAllowInsecureProtocol = true }
    dependencyResolutionManagement.repositories.maven { url = uri("http://127.0.0.1:18082/maven/"); isAllowInsecureProtocol = true }
}
