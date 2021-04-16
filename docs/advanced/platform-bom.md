Using the Platform Bill of Materials (BOM)

Both Gradle[^1] and Maven[^2] define a mechanism that developers can leverage to align the versions of dependencies
that belong to the same framework, or an umbrella of dependencies that need to be aligned to work well together.
Using them will prevent version conflicts and aide you figure out which dependency versions work well with each
other.

Let's go through a scenario, and assume you are using both the `graphql-dgs-spring-boot-starter` and the
`graphql-dgs-subscriptions-websockets-autoconfigure`. Without using the platform/BOM you will have to define a
version for each; unless the versions are explicitly maintained there is a chance that in the future they diverge.
Manually aligning the versions of the dependencies becomes harder if your have a multi-module project where each module
is using different dependencies of the DGS Framework, for example, the `graphql-dgs-client`. **If you are using the
platform/BOM** you define the **version** of the DGS Framework **in one place only**, it will make sure that all other
DGS Framework dependencies are using the same version.

In the case of the DGS Framework we have two different BOM definitions, the `graphql-dgs-platform-dependencies`
and the `graphql-dgs-platform`. The latter only defines version alignment for the DGS modules while the first also
defines versions for the dependencies of the DGS framework, such as Spring, Jackson, and Kotlin.


## Using the Platform/BOM?

Let's go through an example and assume that we want to use the DGS Framework 3.10.2...

=== "Gradle"
    ```groovy
    repositories {
        mavenCentral()
    }

    dependencies {
        // DGS BOM/platform dependency. This is the only place you set version of DGS
        implementation(platform('com.netflix.graphql.dgs:graphql-dgs-platform-dependencies:3.10.2'))

        // DGS dependencies. We don't have to specify a version here!
        implementation 'com.netflix.graphql.dgs:graphql-dgs-spring-boot-starter'
        implementation 'com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure'

        //Additional Jackson dependency. We don't need to specify a version, because Jackson is part of the BOM/platform definition.
        implementation 'com.fasterxml.jackson.datatype:jackson-datatype-joda'

        //Other dependencies...
    }
    ```
=== "Gradle Kotlin"
    ```kotlin
    repositories {
        mavenCentral()
    }

    dependencies {
        //DGS BOM/platform dependency. This is the only place you set version of DGS
        implementation(platform("com.netflix.graphql.dgs:graphql-dgs-platform-dependencies:3.10.2"))

        //DGS dependencies. We don't have to specify a version here!
        implementation("com.netflix.graphql.dgs:graphql-dgs-spring-boot-starter")
        implementation("com.netflix.graphql.dgs:graphql-dgs-subscriptions-websockets-autoconfigure")

        //Additional Jackson dependency. We don't need to specify a version, because Jackson is part of the BOM/platform definition.
        implementation("com.fasterxml.jackson.datatype:jackson-datatype-joda")

        //Other dependencies...
    }
    ```
=== "Maven"
    ```xml
    <dependencyManagement>
        <dependencies>
          <dependency>
            <groupId>com.netflix.graphql.dgs</groupId>
            <artifactId>graphql-dgs-platform-dependencies</artifactId>
            <!-- The DGS BOM/platform dependency. This is the only place you set version of DGS -->
            <version>3.10.2</version>
            <type>pom</type>
            <scope>import</scope>
          </dependency>
        </dependencies>
    </dependencyManagement>
    <dependencies>
        <!-- DGS dependencies. We don't have to specify a version here! -->
        <dependency>
            <groupId>com.netflix.graphql.dgs</groupId>
            <artifactId>graphql-dgs-spring-boot-starter</artifactId>
        </dependency>
        <dependency>
            <groupId>com.netflix.graphql.dgs</groupId>
            <artifactId>graphql-dgs-subscriptions-websockets-autoconfigure</artifactId>
        </dependency>
        <!-- Additional Jackson dependency. We don't need to specify a version, because Jackson is part of the BOM/platform definition. -->
        <dependency>
            <groupId>com.fasterxml.jackson.datatype</groupId>
            <artifactId>jackson-datatype-joda</artifactId>
        </dependency>
        <!-- Other dependencies -->
    </dependencies>
    ```

Notice that **the version is only specified on the platform dependency**, and not on the `graphql-dgs-spring-boot-starter`
and `graphql-dgs-subscriptions-websockets-autoconfigure`. The BOM will make sure that all DGS dependencies are aligned,
in other words, using the same version. In addition, since we are using the `graphql-dgs-platform-dependencies`,
we can use the DGS chosen version of some dependencies as well, such as Jackson.

!!!note
    Versions in the platform are recommendations. The versions can be overridden by the user,
    or by other platforms you might be using (such as the Spring dependency-management plugin).

[^1]: Gradle supports this via the [Java Platform](https://docs.gradle.org/current/userguide/java_platform_plugin.html), checkout the section that describes how to [consume a Java platform](https://docs.gradle.org/current/userguide/java_platform_plugin.html#sec:java_platform_consumption).

[^2]: Maven supports this via the [BOM](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html#bill-of-materials-bom-poms). Note that the BOM will be consumed via the `dependencyManagement` block.
