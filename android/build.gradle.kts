// 📄 Dosya: android/build.gradle.kts
// 📌 Açıklama: Flutter clean desteği ve özelleştirilmiş build dizini

// Build dizinini özelleştirme
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

// Alt projeler için build dizini yapılandırması
subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // :app modülüne bağımlılığı zorunlu kıl
    project.evaluationDependsOn(":app")
}

// Temizleme görevi (flutter clean benzeri)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    // Ek temizleme: Gradle önbelleğini ve geçici dosyaları sil
    delete(rootProject.file("build"))
    delete(rootProject.file(".gradle"))
    delete(rootProject.file("app/build"))
    println("Temizleme tamamlandı: ${rootProject.layout.buildDirectory}")
}

// Tüm projeler için ek yapılandırmalar
allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Gradle performans optimizasyonları
    gradle.projectsEvaluated {
        tasks.withType<JavaCompile> {
            options.isIncremental = true // Artımlı derleme etkinleştirildi
            // Bellek ayarları gradle.properties'e taşındı
        }
    }
}

// Gradle özelliklerini yapılandırma
tasks.withType<org.gradle.api.tasks.compile.JavaCompile> {
    options.encoding = "UTF-8"
    options.isFork = true // Ayrı bir işlemde derleme
    options.forkOptions.memoryMaximumSize = "2g" // Maksimum bellek ayarı
}