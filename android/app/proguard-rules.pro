# Regras de Proguard / R8 para o Frila Android (RNF04/RN15/RF03/RF07/RF13)
# Cartão Trello X0xsdpSU

# Preservar anotações necessárias para serialização e reflexão essencial
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature, Exceptions

# KotlinX Serialization (RF03/RF07/RF13)
# Mantém classes com @Serializable, seus serializadores gerados e o objeto Companion
-keep @kotlinx.serialization.Serializable class * { *; }

-keepclassmembers @kotlinx.serialization.Serializable class * {
    *** Companion;
    *** serializer(...);
}

-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

-keep class kotlinx.serialization.** { *; }

-keepclassmembers class * implements kotlinx.serialization.KSerializer {
    *** descriptor;
    <init>(...);
}

# DTOs de Comunicação com Supabase REST/RPC e Edge Functions (:core:rede)
-keep class br.com.frila.core.rede.** { *; }
-keepclassmembers class br.com.frila.core.rede.** { *; }

# Modelos do Domínio (:core:dominio)
-keep class br.com.frila.core.dominio.modelo.** { *; }
-keepclassmembers class br.com.frila.core.dominio.modelo.** { *; }

# Revisão ANBU (PR #557): removidos os -keep indiscriminados de io.ktor.**, org.koin.**
# e androidx.security.crypto.** que estavam aqui — MEDIDO em mapping.txt do build anterior,
# preservavam ~1996 classes de Ktor e ~439 de Koin inalteradas, anulando a ofuscação dessas
# bibliotecas. Ktor, Koin e androidx.security.crypto já publicam suas próprias consumer
# ProGuard rules (embutidas no .aar) e não usam reflexão bruta sobre tipo do app — não
# precisam de keep aqui; os keeps acima bastam para serialização e para os DTOs/modelos
# do próprio app, que são os únicos pontos refletidos via KotlinX Serialization.

# Otimização e Ofuscação R8
-repackageclasses 'br.com.frila.o'
-allowaccessmodification

# Remoção de logs informativos/debug em release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Classes opcionais de JVM desktop referenciadas por Ktor e SLF4J
-dontwarn java.lang.management.**
-dontwarn org.slf4j.impl.**
